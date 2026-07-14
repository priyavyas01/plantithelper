import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_it_helper/screens/auth/reset_password_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

const _email = 'test@example.com';

void main() {
  group('ResetPasswordScreen', () {
    testWidgets('shows code, new password, and confirm fields', (tester) async {
      await tester.pumpWidget(_wrap(const ResetPasswordScreen(email: _email)));
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Reset Code'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'New Password'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Confirm New Password'), findsOneWidget);
    });

    testWidgets('shows error when code is empty', (tester) async {
      await tester.pumpWidget(_wrap(const ResetPasswordScreen(email: _email)));
      await tester.tap(find.text('Reset Password').last);
      await tester.pump();
      expect(find.text('Code is required'), findsOneWidget);
    });

    testWidgets('shows error when code is less than 6 digits', (tester) async {
      await tester.pumpWidget(_wrap(const ResetPasswordScreen(email: _email)));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '123');
      await tester.tap(find.text('Reset Password').last);
      await tester.pump();
      expect(find.text('Code must be 6 digits'), findsOneWidget);
    });

    testWidgets('shows error when passwords do not match', (tester) async {
      await tester.pumpWidget(_wrap(const ResetPasswordScreen(email: _email)));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '123456');
      await tester.enterText(fields.at(1), 'password1');
      await tester.enterText(fields.at(2), 'password2');
      await tester.tap(find.text('Reset Password').last);
      await tester.pump();
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('shows error when password is too short', (tester) async {
      await tester.pumpWidget(_wrap(const ResetPasswordScreen(email: _email)));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '123456');
      await tester.enterText(fields.at(1), 'short');
      await tester.enterText(fields.at(2), 'short');
      await tester.tap(find.text('Reset Password').last);
      await tester.pump();
      expect(find.text('At least 8 characters'), findsOneWidget);
    });
  });
}
