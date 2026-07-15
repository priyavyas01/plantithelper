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

class PlantService {
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
