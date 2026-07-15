import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plant_it_helper/models/scan_models.dart';
import 'package:plant_it_helper/screens/scan/result_screen.dart';
import 'package:plant_it_helper/services/plant_service.dart';

// ---------------------------------------------------------------------------
// Shared test fixtures
// ---------------------------------------------------------------------------

final _mockResult = ScanResult(
  commonName: 'Monstera',
  scientificName: 'Monstera deliciosa',
  confidence: 'high',
  health: 'healthy',
  healthObservation: 'Leaves look vibrant and full.',
  care: CareInfo(
    light: 'Bright indirect light',
    water: 'Water when dry',
    humidity: '60%',
    temperature: '18-27C',
    tips: ['Wipe leaves'],
  ),
  funFact: 'Leaves develop holes as they mature.',
);

/// Wraps [ResultScreen] in a MaterialApp + Navigator so modals work.
Widget buildScreen({
  required Future<SavedPlant> Function(SavePlantRequest) onSave,
}) {
  return MaterialApp(
    home: Navigator(
      pages: [
        const MaterialPage(child: Scaffold(body: Text('Capture'))),
        const MaterialPage(child: Scaffold(body: Text('Preview'))),
        MaterialPage(
          child: ResultScreen(result: _mockResult, onSave: onSave),
        ),
      ],
      onDidRemovePage: (_) {},
    ),
  );
}

/// Opens the save bottom sheet. Scrolls the button into view first because
/// the care grid pushes it below the 600px test viewport height.
Future<void> openSaveSheet(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save This Plant'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save This Plant'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ResultScreen save flow', () {
    testWidgets('shows Save This Plant button initially', (tester) async {
      await tester.pumpWidget(buildScreen(onSave: (_) async => throw UnimplementedError()));
      expect(find.text('Save This Plant'), findsOneWidget);
    });

    testWidgets('tapping Save This Plant opens bottom sheet with pre-filled name',
        (tester) async {
      await tester.pumpWidget(buildScreen(onSave: (_) async => throw UnimplementedError()));
      await openSaveSheet(tester);

      expect(find.text('Save Plant'), findsOneWidget);
      // Name field pre-filled with 'Monstera'
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text, 'Monstera');
    });

    testWidgets('empty name shows inline validation error', (tester) async {
      await tester.pumpWidget(buildScreen(onSave: (_) async => throw UnimplementedError()));
      await openSaveSheet(tester);

      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();

      expect(find.text('Please give your plant a name'), findsOneWidget);
    });

    testWidgets('save button is disabled while request is in-flight', (tester) async {
      final completer = Completer<SavedPlant>();
      await tester.pumpWidget(buildScreen(onSave: (_) => completer.future));
      await openSaveSheet(tester);

      // Tap Save — button shows 'Save' right now
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump(); // one frame — spinner shown, no 'Save' text

      // While in-flight the button child is a spinner (no text), so the
      // text-based finder returns nothing — confirms button is in loading state
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);

      completer.complete(SavedPlant(id: 'id', name: 'Monstera', createdAt: DateTime.now()));
    });

    testWidgets('on success: sheet closes, button changes to Saved, snackbar appears',
        (tester) async {
      await tester.pumpWidget(buildScreen(
        onSave: (_) async => SavedPlant(id: 'abc', name: 'Monstera', createdAt: DateTime.now()),
      ));

      await openSaveSheet(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Save Plant'), findsNothing);   // sheet closed
      expect(find.text('Saved'), findsOneWidget);       // button updated
      expect(find.text('Plant saved!'), findsOneWidget); // snackbar
    });

    testWidgets('on error: error message shown in sheet, sheet stays open',
        (tester) async {
      await tester.pumpWidget(buildScreen(
        onSave: (_) async => throw const PlantSaveException('Could not save. Try again.'),
      ));

      await openSaveSheet(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Save Plant'), findsOneWidget);                   // sheet still open
      expect(find.text('Could not save. Try again.'), findsOneWidget);   // error shown

      // Save button re-enabled so user can retry
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save').first,
      );
      expect(saveButton.onPressed, isNotNull);
    });
  });
}
