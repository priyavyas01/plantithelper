import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_it_helper/screens/auth/forgot_password_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('ForgotPasswordScreen', () {
    testWidgets('shows email field and submit button', (tester) async {
      await tester.pumpWidget(_wrap(const ForgotPasswordScreen()));
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.text('Send Reset Code'), findsOneWidget);
    });

    testWidgets('shows error when email is empty', (tester) async {
      await tester.pumpWidget(_wrap(const ForgotPasswordScreen()));
      await tester.tap(find.text('Send Reset Code'));
      await tester.pump();
      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('shows error for invalid email format', (tester) async {
      await tester.pumpWidget(_wrap(const ForgotPasswordScreen()));
      await tester.enterText(find.byType(TextFormField), 'notanemail');
      await tester.tap(find.text('Send Reset Code'));
      await tester.pump();
      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('shows network error when server unreachable', (tester) async {
      await tester.pumpWidget(_wrap(const ForgotPasswordScreen()));
      await tester.enterText(find.byType(TextFormField), 'test@example.com');
      await tester.tap(find.text('Send Reset Code'));
      await tester.pump();        // starts loading
      await tester.pump(const Duration(seconds: 5)); // wait for timeout
      expect(find.text('Could not connect to server. Try again.'), findsOneWidget);
    });
  });
}
