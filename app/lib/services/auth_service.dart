import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/auth_models.dart';

class AuthService {
  // Change to your machine's IP if testing on a physical device
  static const String _baseUrl = 'http://localhost:8000';

  static Future<TokenResponse> register({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return TokenResponse.fromJson(body);
    }

    throw AuthError(body['detail'] ?? 'Registration failed');
  }

  static Future<TokenResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return TokenResponse.fromJson(body);
    }

    throw AuthError(body['detail'] ?? 'Login failed');
  }

  static Future<void> logout({required String refreshToken}) async {
    await http.post(
      Uri.parse('$_baseUrl/auth/logout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
  }

  static Future<void> forgotPassword({required String email}) async {
    final response = await http.post(
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
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'code': code,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode != 204) {
      final body = jsonDecode(response.body);
      throw AuthError(body['detail'] ?? 'Invalid or expired code.');
    }
  }
}
