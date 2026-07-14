import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:plant_it_helper/main.dart';
import 'package:plant_it_helper/screens/splash_screen.dart';

void main() {
  testWidgets('app starts and shows splash screen', (WidgetTester tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );

    await tester.pumpWidget(const PlantItApp());
    expect(find.byType(SplashScreen), findsOneWidget);

    // Cancel pending timers from the 500ms delay in _checkAuth
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });
}
