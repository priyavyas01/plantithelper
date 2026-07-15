import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/scan_models.dart';
import '../services/token_service.dart';

/// Thrown when POST /plants does not return 201.
class PlantSaveException implements Exception {
  final String message;
  final int? statusCode;
  const PlantSaveException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Thrown when a plants API call fails unexpectedly.
class PlantFetchException implements Exception {
  final String message;
  final int? statusCode;
  const PlantFetchException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Result wrapper for [PlantService.getPlants].
/// [fromCache] is true when the network call failed and stale cached data
/// was returned instead. The UI shows a banner in this case.
class PlantListResult {
  final List<PlantListItem> plants;
  final bool fromCache;
  const PlantListResult(this.plants, {this.fromCache = false});
}

// ---------------------------------------------------------------------------
// In-memory cache
// Valid until explicitly cleared (logout, save, delete).
// Not persisted across app restarts — shared_preferences is a future story.
// ---------------------------------------------------------------------------
class _PlantCache {
  static List<PlantListItem>? plantList;
  static final Map<String, PlantDetail> plantDetails = {};

  static void clear() {
    plantList = null;
    plantDetails.clear();
    debugPrint('[PlantService] [CACHE CLEAR] all entries removed');
  }
}

class PlantService {
  // Swappable HTTP client — allows tests to inject a mock without network.
  static http.Client _client = http.Client();
  // ignore: use_setters_to_change_properties
  static void setHttpClient(http.Client client) => _client = client;

  /// Clears all cached plant data.
  /// Must be called on logout so one user cannot see another's data on a
  /// shared device.
  static void clearCache() => _PlantCache.clear();

  /// GET /plants — returns the current user's saved plants, newest first.
  ///
  /// On success: writes the list to cache and returns [fromCache]=false.
  /// On network failure: returns the cached list with [fromCache]=true.
  /// Throws [PlantFetchException] when the call fails and no cache exists.
  static Future<PlantListResult> getPlants() async {
    final token = await TokenService.getAccessToken();
    if (token == null) {
      debugPrint('[PlantService] ERROR no access token');
      throw const PlantFetchException('Not authenticated', statusCode: 401);
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/plants');
    debugPrint('[PlantService] GET /plants');

    try {
      final response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));

      debugPrint('[PlantService] GET /plants → ${response.statusCode}');

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        final plants = list
            .map((e) => PlantListItem.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('[PlantService] [CACHE SET] list → ${plants.length} plants');
        _PlantCache.plantList = plants;
        return PlantListResult(plants);
      }

      if (response.statusCode == 401) {
        throw const PlantFetchException('Session expired.', statusCode: 401);
      }

      throw PlantFetchException(
        'Could not load plants.',
        statusCode: response.statusCode,
      );
    } on PlantFetchException {
      rethrow; // 401/non-200 — do not fall back to cache
    } catch (e) {
      // Network error, timeout, DNS failure, etc.
      debugPrint('[PlantService] GET /plants network error: $e');
      final cached = _PlantCache.plantList;
      if (cached != null) {
        debugPrint('[PlantService] [CACHE HIT] list → ${cached.length} plants (network unavailable)');
        return PlantListResult(cached, fromCache: true);
      }
      throw const PlantFetchException(
        'Could not load plants. Check your connection.',
      );
    }
  }

  /// GET /plants/{id} — returns full detail including care guide.
  ///
  /// On success: caches the result.
  /// On network failure: returns the cached detail silently (no banner needed
  /// for a detail screen — the data is unlikely to have changed).
  /// Throws [PlantFetchException] when the call fails and no cache exists.
  static Future<PlantDetail> getPlant(String id) async {
    final token = await TokenService.getAccessToken();
    if (token == null) {
      debugPrint('[PlantService] ERROR no access token');
      throw const PlantFetchException('Not authenticated', statusCode: 401);
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/plants/$id');
    debugPrint('[PlantService] GET /plants/$id');

    try {
      final response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));

      debugPrint('[PlantService] GET /plants/$id → ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final plant = PlantDetail.fromJson(data);
        debugPrint('[PlantService] [CACHE SET] detail → ${plant.name} (id=$id)');
        _PlantCache.plantDetails[id] = plant;
        return plant;
      }

      if (response.statusCode == 401) {
        throw const PlantFetchException('Session expired.', statusCode: 401);
      }
      if (response.statusCode == 404) {
        throw const PlantFetchException('Plant not found.', statusCode: 404);
      }

      throw PlantFetchException(
        'Could not load plant.',
        statusCode: response.statusCode,
      );
    } on PlantFetchException {
      rethrow;
    } catch (e) {
      debugPrint('[PlantService] GET /plants/$id network error: $e');
      final cached = _PlantCache.plantDetails[id];
      if (cached != null) {
        debugPrint('[PlantService] [CACHE HIT] detail → id=$id (network unavailable)');
        return cached;
      }
      throw const PlantFetchException(
        'Could not load plant. Check your connection.',
      );
    }
  }

  /// DELETE /plants/{id} — permanently removes a plant.
  ///
  /// Invalidates the list cache and removes the plant's own detail entry
  /// so stale data is never shown after deletion.
  static Future<void> deletePlant(String id) async {
    final token = await TokenService.getAccessToken();
    if (token == null) {
      debugPrint('[PlantService] ERROR no access token');
      throw const PlantFetchException('Not authenticated', statusCode: 401);
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/plants/$id');
    debugPrint('[PlantService] DELETE /plants/$id');

    final response = await _client
        .delete(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15));

    debugPrint('[PlantService] DELETE /plants/$id → ${response.statusCode}');

    if (response.statusCode == 204) {
      _PlantCache.plantList = null;
      _PlantCache.plantDetails.remove(id);
      debugPrint('[PlantService] [CACHE CLEAR] delete → removed list + detail for id=$id');
      return;
    }

    if (response.statusCode == 401) {
      throw const PlantFetchException('Session expired.', statusCode: 401);
    }
    if (response.statusCode == 404) {
      throw const PlantFetchException('Plant not found.', statusCode: 404);
    }

    throw PlantFetchException(
      'Could not delete plant.',
      statusCode: response.statusCode,
    );
  }

  /// POST /plants — saves a scanned plant to the user's collection.
  ///
  /// Invalidates the list cache so the new plant appears on next load.
  /// Throws [PlantSaveException] on any non-201 response.
  static Future<SavedPlant> savePlant(SavePlantRequest request) async {
    final token = await TokenService.getAccessToken();
    if (token == null) {
      debugPrint('[PlantService] ERROR no access token');
      throw const PlantSaveException('Not authenticated', statusCode: 401);
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/plants');
    debugPrint('[PlantService] POST /plants | name=${request.name}');

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(request.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    debugPrint('[PlantService] POST /plants → ${response.statusCode}');

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final saved = SavedPlant.fromJson(data);
      _PlantCache.plantList = null;
      debugPrint('[PlantService] [CACHE CLEAR] save → list invalidated (new plant ${saved.id})');
      return saved;
    }

    if (response.statusCode == 401) {
      throw const PlantSaveException(
        'Session expired. Please log in again.',
        statusCode: 401,
      );
    }
    if (response.statusCode == 422) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail']?.toString() ?? 'Invalid data';
      throw PlantSaveException(detail, statusCode: 422);
    }

    throw PlantSaveException(
      'Could not save. Try again.',
      statusCode: response.statusCode,
    );
  }
}
