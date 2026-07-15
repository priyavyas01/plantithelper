import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_it_helper/models/scan_models.dart';
import 'package:plant_it_helper/screens/scan/result_screen.dart';

ScanResult _mockResult({String confidence = 'high'}) => ScanResult(
      commonName: 'Monstera',
      scientificName: 'Monstera deliciosa',
      confidence: confidence,
      care: const CareInfo(
        light: 'Bright indirect light',
        water: 'Once a week',
        humidity: 'High (60%+)',
        temperature: '18–27°C',
        tips: ['Wipe leaves monthly'],
      ),
      funFact: 'Holes in leaves reduce wind resistance.',
    );

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('ResultScreen', () {
    testWidgets('shows common name and scientific name', (tester) async {
      await tester.pumpWidget(_wrap(ResultScreen(result: _mockResult())));
      expect(find.text('Monstera'), findsOneWidget);
      expect(find.text('Monstera deliciosa'), findsOneWidget);
    });

    testWidgets('shows High confidence badge', (tester) async {
      await tester.pumpWidget(_wrap(ResultScreen(result: _mockResult())));
      expect(find.text('High confidence'), findsOneWidget);
    });

    testWidgets('shows Medium confidence badge', (tester) async {
      await tester.pumpWidget(
        _wrap(ResultScreen(result: _mockResult(confidence: 'medium'))),
      );
      expect(find.text('Medium confidence'), findsOneWidget);
    });

    testWidgets('shows Low confidence badge', (tester) async {
      await tester.pumpWidget(
        _wrap(ResultScreen(result: _mockResult(confidence: 'low'))),
      );
      expect(find.text('Low confidence'), findsOneWidget);
    });

    testWidgets('shows all four care card labels', (tester) async {
      await tester.pumpWidget(_wrap(ResultScreen(result: _mockResult())));
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Humidity'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
    });

    testWidgets('shows Save and Scan Another buttons', (tester) async {
      await tester.pumpWidget(_wrap(ResultScreen(result: _mockResult())));
      expect(find.text('Save This Plant'), findsOneWidget);
      expect(find.text('Scan Another Plant'), findsOneWidget);
    });

    testWidgets('Scan Another pops back past ResultScreen', (tester) async {
      // Push ResultScreen on top of a placeholder to verify double-pop works
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).push(
            MaterialPageRoute(
              builder: (_) => ResultScreen(result: _mockResult()),
            ),
          ),
          child: const Text('Open'),
        )),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Scan Another Plant'), findsOneWidget);

      await tester.tap(find.text('Scan Another Plant'));
      await tester.pumpAndSettle();
      // ResultScreen is gone — we're back on the placeholder
      expect(find.text('Scan Another Plant'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });
  });
}
