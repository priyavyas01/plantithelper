import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/token_service.dart';
import '../../models/auth_models.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 500)); // brief pause for splash

    final accessToken = await TokenService.getAccessToken();
    final refreshToken = await TokenService.getRefreshToken();

    if (accessToken == null || refreshToken == null) {
      _goToLogin();
      return;
    }

    // Try the access token first
    try {
      await AuthService.getMe(accessToken: accessToken);
      _goToHome();
      return;
    } on AuthError catch (e) {
      if (e.statusCode != 401) {
        // Unexpected error (server down, etc.) — send to login
        _goToLogin();
        return;
      }
    } catch (_) {
      _goToLogin();
      return;
    }

    // Access token expired — try refreshing
    try {
      final tokens = await AuthService.refreshTokens(refreshToken: refreshToken);
      await TokenService.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      _goToHome();
    } catch (_) {
      // Refresh token also expired or revoked — clear everything and go to login
      await TokenService.clearTokens();
      _goToLogin();
    }
  }

  void _goToHome() {
    if (mounted) Navigator.of(context).pushReplacementNamed('/home');
  }

  void _goToLogin() {
    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 72, color: Color(0xFF4CAF50)),
            SizedBox(height: 16),
            Text(
              'PlantIt Helper',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Color(0xFF4CAF50)),
          ],
        ),
      ),
    );
  }
}
