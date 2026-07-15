import 'dart:convert';
import 'dart:developer' as dev;
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
    dev.log(
      'scan started | size_bytes=${imageBytes.length}',
      name: 'ScanService',
    );

    final uri = Uri.parse('${AppConfig.baseUrl}/scan');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'plant.jpg',
        ),
      );

    dev.log('sending multipart request | url=$uri', name: 'ScanService');

    final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          dev.log('scan timed out after 30s', name: 'ScanService');
          throw ScanException(
            'Request timed out. Please try again.',
            statusCode: 408,
          );
        },
      );
    } catch (e) {
      if (e is ScanException) rethrow;
      dev.log(
        'network error | could not reach server',
        name: 'ScanService',
        error: e,
      );
      throw ScanException(
        'Could not connect to server. Check your network.',
        statusCode: 0,
      );
    }

    final response = await http.Response.fromStream(streamed);
    dev.log(
      'response received | status=${response.statusCode}',
      name: 'ScanService',
    );

    if (response.statusCode == 200) {
      final result = ScanResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      dev.log(
        'scan complete | name="${result.commonName}" confidence=${result.confidence}',
        name: 'ScanService',
      );
      return result;
    }

    if (response.statusCode == 422) {
      dev.log('not a plant detected | 422 returned', name: 'ScanService');
      throw ScanException(
        'No plant detected. Try a clearer photo.',
        statusCode: 422,
      );
    }

    if (response.statusCode == 401) {
      dev.log('unauthorized | 401 returned', name: 'ScanService');
      throw ScanException(
        'Session expired. Please log in again.',
        statusCode: 401,
      );
    }

    dev.log(
      'scan failed | status=${response.statusCode}',
      name: 'ScanService',
    );
    throw ScanException(
      'Something went wrong. Please try again.',
      statusCode: response.statusCode,
    );
  }
}
