import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plant_it_helper/screens/splash_screen.dart';
import 'package:plant_it_helper/screens/auth/login_screen.dart';
import 'package:plant_it_helper/screens/home/home_screen.dart';
import 'package:plant_it_helper/services/auth_service.dart';

// Minimal app wrapper with the routes SplashScreen navigates to
Widget _app({Map<String, String> storage = const {}}) {
  FlutterSecureStorageMock.setup(storage);
  return MaterialApp(
    initialRoute: '/splash',
    routes: {
      '/splash': (_) => const SplashScreen(),
      '/login': (_) => const LoginScreen(),
      '/home': (_) => const HomeScreen(),
    },
  );
}

// Mocks the flutter_secure_storage method channel so tests don't need a real device
class FlutterSecureStorageMock {
  static final Map<String, String> _store = {};

  static void setup(Map<String, String> initial) {
    _store
      ..clear()
      ..addAll(initial);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        switch (call.method) {
          case 'read':
            return _store[call.arguments['key'] as String];
          case 'write':
            _store[call.arguments['key'] as String] =
                call.arguments['value'] as String;
            return null;
          case 'delete':
            _store.remove(call.arguments['key'] as String);
            return null;
          default:
            return null;
        }
      },
    );
  }
}

void main() {
  tearDown(() => AuthService.resetHttpClient());

  // AC-1: valid access token → straight to home
  testWidgets('AC-1: valid access token routes to /home', (tester) async {
    AuthService.setHttpClient(MockClient((_) async =>
        http.Response(jsonEncode({'id': '1', 'email': 'a@b.com'}), 200)));

    await tester.pumpWidget(_app(storage: {
      'access_token': 'valid-token',
      'refresh_token': 'valid-refresh',
    }));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  // AC-2: expired access token but valid refresh → silent refresh → home
  testWidgets('AC-2: expired access, valid refresh → silent refresh → /home',
      (tester) async {
    int callCount = 0;
    AuthService.setHttpClient(MockClient((request) async {
      callCount++;
      if (request.url.path.endsWith('/auth/me')) {
        return http.Response('{"detail":"Unauthorized"}', 401);
      }
      if (request.url.path.endsWith('/auth/refresh')) {
        return http.Response(
            jsonEncode({'access_token': 'new-access', 'refresh_token': 'new-refresh',
                        'token_type': 'bearer'}), 200);
      }
      return http.Response('', 500);
    }));

    await tester.pumpWidget(_app(storage: {
      'access_token': 'expired-token',
      'refresh_token': 'valid-refresh',
    }));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(callCount, 2); // /me then /refresh
  });

  // AC-3: no tokens stored → login
  testWidgets('AC-3: no tokens stored → /login', (tester) async {
    AuthService.setHttpClient(MockClient((_) async => http.Response('', 500)));

    await tester.pumpWidget(_app()); // empty storage
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  // AC-4: both tokens expired → clear tokens → login
  testWidgets('AC-4: both tokens expired → clear storage → /login',
      (tester) async {
    AuthService.setHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/auth/me')) {
        return http.Response('{"detail":"Unauthorized"}', 401);
      }
      return http.Response('{"detail":"Unauthorized"}', 401); // refresh also fails
    }));

    await tester.pumpWidget(_app(storage: {
      'access_token': 'expired-access',
      'refresh_token': 'expired-refresh',
    }));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  // AC-5: server unreachable → login (never hang on splash)
  testWidgets('AC-5: server unreachable → /login', (tester) async {
    AuthService.setHttpClient(
        MockClient((_) async => throw Exception('Connection refused')));

    await tester.pumpWidget(_app(storage: {
      'access_token': 'some-token',
      'refresh_token': 'some-refresh',
    }));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
