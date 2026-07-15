import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_it_helper/models/scan_models.dart';
import 'package:plant_it_helper/screens/scan/result_screen.dart';

ScanResult _mockResult({String confidence = 'high', String health = 'healthy'}) => ScanResult(
      commonName: 'Monstera',
      scientificName: 'Monstera deliciosa',
      confidence: confidence,
      health: health,
      healthObservation: 'Leaves look vibrant and full.',
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

    testWidgets('shows Healthy health badge', (tester) async {
      await tester.pumpWidget(_wrap(ResultScreen(result: _mockResult(health: 'healthy'))));
      expect(find.text('Healthy'), findsOneWidget);
    });

    testWidgets('shows Needs Attention health badge', (tester) async {
      await tester.pumpWidget(
        _wrap(ResultScreen(result: _mockResult(health: 'needs_attention'))),
      );
      expect(find.text('Needs Attention'), findsOneWidget);
    });

    testWidgets('shows Concerning health badge', (tester) async {
      await tester.pumpWidget(
        _wrap(ResultScreen(result: _mockResult(health: 'concerning'))),
      );
      expect(find.text('Concerning'), findsOneWidget);
    });

    testWidgets('shows health observation text', (tester) async {
      await tester.pumpWidget(_wrap(ResultScreen(result: _mockResult())));
      expect(find.text('Leaves look vibrant and full.'), findsOneWidget);
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
      // The real app stack is CaptureScreen → PreviewScreen → ResultScreen.
      // We need THREE levels so the double-pop lands on the root, not below it.
      // Two placeholder levels simulate Capture and Preview.
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (captureCtx) => TextButton(
          onPressed: () => Navigator.of(captureCtx).push(
            MaterialPageRoute(builder: (_) => Builder(
              builder: (previewCtx) => TextButton(
                onPressed: () => Navigator.of(previewCtx).push(
                  MaterialPageRoute(
                    builder: (_) => ResultScreen(result: _mockResult()),
                  ),
                ),
                child: const Text('GoToResult'),
              ),
            )),
          ),
          child: const Text('Capture'),
        )),
      ));

      // Navigate: Capture → Preview → ResultScreen
      await tester.tap(find.text('Capture'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GoToResult'));
      await tester.pumpAndSettle();
      expect(find.text('Scan Another Plant'), findsOneWidget);

      // Double-pop: removes ResultScreen then Preview → lands on Capture
      await tester.ensureVisible(find.text('Scan Another Plant'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scan Another Plant'));
      await tester.pumpAndSettle();
      expect(find.text('Scan Another Plant'), findsNothing);
      expect(find.text('Capture'), findsOneWidget);
    });
  });
}
