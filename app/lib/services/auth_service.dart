import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/auth_models.dart';

class AuthService {
  // On a physical device, localhost means the phone itself — not your laptop.
  // Use your laptop's WiFi IP (run `ipconfig getifaddr en0` on Mac) when
  // testing on a real device. On simulators, localhost works fine.
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  // Swappable in tests via setHttpClient() — production code never touches this
  static http.Client _client = http.Client();

  @visibleForTesting
  static void setHttpClient(http.Client client) => _client = client;

  @visibleForTesting
  static void resetHttpClient() => _client = http.Client();

  static Future<TokenResponse> register({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode == 201) return TokenResponse.fromJson(body);
    throw AuthError(body['detail'] ?? 'Registration failed');
  }

  static Future<TokenResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) return TokenResponse.fromJson(body);
    throw AuthError(body['detail'] ?? 'Login failed');
  }

  static Future<void> logout({required String refreshToken}) async {
    await _client.post(
      Uri.parse('$_baseUrl/auth/logout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
  }

  // AC-1: verify access token is still valid
  static Future<void> getMe({required String accessToken}) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw AuthError('Unauthorized', statusCode: response.statusCode);
    }
  }

  // AC-2: called when getMe returns 401
  static Future<TokenResponse> refreshTokens({required String refreshToken}) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    if (response.statusCode == 200) {
      return TokenResponse.fromJson(jsonDecode(response.body));
    }
    throw AuthError('Session expired', statusCode: response.statusCode);
  }

  static Future<void> forgotPassword({required String email}) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode != 204) {
      final body = jsonDecode(response.body);
      throw AuthError(body['detail'] ?? 'Something went wrong. Try again.');
    }
  }

  static Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code, 'new_password': newPassword}),
    );
    if (response.statusCode != 204) {
      final body = jsonDecode(response.body);
      throw AuthError(body['detail'] ?? 'Invalid or expired code.');
    }
  }
}
