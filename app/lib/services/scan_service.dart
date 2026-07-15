import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/scan_models.dart';

class ScanException implements Exception {
  final String message;
  final int statusCode;

  const ScanException(this.message, {required this.statusCode});

  @override
  String toString() => 'ScanException($statusCode): $message';
}

class ScanService {
  // Swappable in tests via setHttpClient() — production code never touches this
  static http.Client _client = http.Client();

  @visibleForTesting
  static void setHttpClient(http.Client client) => _client = client;

  @visibleForTesting
  static void resetHttpClient() => _client = http.Client();

  static Future<ScanResult> scanPlant({
    required Uint8List imageBytes,
    required String accessToken,
  }) async {
    debugPrint('[ScanService] scan started | size_bytes=${imageBytes.length}');

    final uri = Uri.parse('${AppConfig.baseUrl}/scan');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'plant.jpg',
        ),
      );

    debugPrint('[ScanService] POST $uri');

    final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('[ScanService] ERROR request timed out after 30s');
          throw ScanException(
            'Request timed out. Please try again.',
            statusCode: 408,
          );
        },
      );
    } catch (e) {
      if (e is ScanException) rethrow;
      debugPrint('[ScanService] ERROR network error | $e');
      throw ScanException(
        'Could not connect to server. Check your network.',
        statusCode: 0,
      );
    }

    final response = await http.Response.fromStream(streamed);
    debugPrint('[ScanService] response status=${response.statusCode}');

    if (response.statusCode == 200) {
      final result = ScanResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      debugPrint('[ScanService] scan complete | name="${result.commonName}" confidence=${result.confidence}');
      return result;
    }

    if (response.statusCode == 422) {
      debugPrint('[ScanService] 422 no plant detected');
      throw ScanException(
        'No plant detected. Try a clearer photo.',
        statusCode: 422,
      );
    }

    if (response.statusCode == 401) {
      debugPrint('[ScanService] 401 unauthorized - token expired');
      throw ScanException(
        'Session expired. Please log in again.',
        statusCode: 401,
      );
    }

    if (response.statusCode == 413) {
      debugPrint('[ScanService] 413 image too large');
      throw ScanException(
        'Image is too large. Try a smaller photo.',
        statusCode: 413,
      );
    }

    debugPrint('[ScanService] ERROR unexpected status=${response.statusCode}');
    throw ScanException(
      'Something went wrong. Please try again.',
      statusCode: response.statusCode,
    );
  }
}
