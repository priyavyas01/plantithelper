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
}

/// Thrown when a plants API call fails unexpectedly.
class PlantFetchException implements Exception {
  final String message;
  final int? statusCode;
  const PlantFetchException(this.message, {this.statusCode});
}

class PlantService {
  /// GET /plants — returns the current user's saved plants, newest first.
  ///
  /// Throws [PlantFetchException] on any non-200 response.
  static Future<List<PlantListItem>> getPlants() async {
    final token = await TokenService.getAccessToken();
    if (token == null) {
      debugPrint('[PlantService] ERROR no access token');
      throw const PlantFetchException('Not authenticated', statusCode: 401);
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/plants');
    debugPrint('[PlantService] GET /plants');

    final response = await http
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15));

    debugPrint('[PlantService] GET /plants status=${response.statusCode}');

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      final plants = list
          .map((e) => PlantListItem.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('[PlantService] loaded ${plants.length} plants');
      return plants;
    }

    if (response.statusCode == 401) {
      throw const PlantFetchException('Session expired.', statusCode: 401);
    }

    throw PlantFetchException(
      'Could not load plants.',
      statusCode: response.statusCode,
    );
  }

  /// POST /plants — saves the scanned plant to the user's collection.
  ///
  /// Throws [PlantSaveException] on any non-201 response.
  static Future<SavedPlant> savePlant(SavePlantRequest request) async {
    final token = await TokenService.getAccessToken();
    if (token == null) {
      debugPrint('[PlantService] ERROR no access token');
      throw const PlantSaveException('Not authenticated', statusCode: 401);
    }

    final uri = Uri.parse('${AppConfig.baseUrl}/plants');
    debugPrint('[PlantService] POST /plants | name=${request.name}');

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(request.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    debugPrint('[PlantService] response status=${response.statusCode}');

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final saved = SavedPlant.fromJson(data);
      debugPrint('[PlantService] plant saved | id=${saved.id}');
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

    debugPrint('[PlantService] ERROR unexpected status=${response.statusCode}');
    throw PlantSaveException(
      'Could not save. Try again.',
      statusCode: response.statusCode,
    );
  }
}
