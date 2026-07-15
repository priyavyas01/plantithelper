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
      await tester.tap(find.text('Save This Plant'));
      await tester.pumpAndSettle();

      // Sheet should be open with the name field pre-filled
      expect(find.text('Save Plant'), findsOneWidget);
      expect(find.text('Monstera'), findsWidgets); // in field and header
    });

    testWidgets('empty name shows inline validation error', (tester) async {
      await tester.pumpWidget(buildScreen(onSave: (_) async => throw UnimplementedError()));
      await tester.tap(find.text('Save This Plant'));
      await tester.pumpAndSettle();

      // Clear the name field
      await tester.enterText(find.byType(TextFormField), '');
      // Tap the Save button inside the sheet
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();

      expect(find.text('Please give your plant a name'), findsOneWidget);
    });

    testWidgets('save button is disabled while request is in-flight', (tester) async {
      final completer = Completer<SavedPlant>();
      await tester.pumpWidget(buildScreen(onSave: (_) => completer.future));
      await tester.tap(find.text('Save This Plant'));
      await tester.pumpAndSettle();

      // Tap Save to start the in-flight request (button shows 'Save' at this point)
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump(); // one frame — still in-flight, spinner shown

      // The save FilledButton in the sheet is now disabled (onPressed==null).
      // We find it by checking all FilledButtons — the one inside the sheet
      // has no text child while loading (it shows a spinner).
      // Verify by checking there is no enabled FilledButton labelled 'Save'.
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);

      completer.complete(SavedPlant(
        id: 'test-id',
        name: 'Monstera',
        createdAt: DateTime.now(),
      ));
    });

    testWidgets('on success: sheet closes, button changes to Saved, snackbar appears',
        (tester) async {
      await tester.pumpWidget(buildScreen(
        onSave: (_) async => SavedPlant(
          id: 'abc-123',
          name: 'Monstera',
          createdAt: DateTime.now(),
        ),
      ));

      await tester.tap(find.text('Save This Plant'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // Sheet is closed — "Save Plant" header gone
      expect(find.text('Save Plant'), findsNothing);
      // Button now shows "Saved"
      expect(find.text('Saved'), findsOneWidget);
      // Snackbar visible
      expect(find.text('Plant saved!'), findsOneWidget);
    });

    testWidgets('on error: error message shown in sheet, sheet stays open',
        (tester) async {
      await tester.pumpWidget(buildScreen(
        onSave: (_) async =>
            throw const PlantSaveException('Could not save. Try again.'),
      ));

      await tester.tap(find.text('Save This Plant'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // Sheet still open
      expect(find.text('Save Plant'), findsOneWidget);
      // Error message visible
      expect(find.text('Could not save. Try again.'), findsOneWidget);
      // Save button re-enabled for retry
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save').first,
      );
      expect(saveButton.onPressed, isNotNull);
    });
  });
}
