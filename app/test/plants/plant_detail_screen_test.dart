import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_it_helper/screens/plants/plant_detail_screen.dart';
import 'package:plant_it_helper/models/scan_models.dart';
import 'package:plant_it_helper/services/plant_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PlantDetail _makePlant({String? funFact}) => PlantDetail(
      id: 'abc-123',
      name: 'My Monstera',
      commonName: 'Monstera',
      scientificName: 'Monstera deliciosa',
      confidence: 'high',
      care: const CareInfo(
        light: 'Bright indirect',
        water: 'Weekly',
        humidity: 'High',
        temperature: '18-27C',
        tips: ['Wipe leaves monthly'],
      ),
      funFact: funFact,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    );

Widget _wrap(Widget child) => MaterialApp(
      home: child,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PlantDetailScreen', () {
    testWidgets('shows loading indicator while fetch is in-flight',
        (tester) async {
      // getPlant never completes — widget stays in loading state
      await tester.pumpWidget(_wrap(
        PlantDetailScreen(
          plantId: 'abc-123',
          getPlant: (_) => Completer<PlantDetail>().future,
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows plant name and scientific name after load',
        (tester) async {
      final plant = _makePlant();
      await tester.pumpWidget(_wrap(
        PlantDetailScreen(
          plantId: 'abc-123',
          getPlant: (_) async => plant,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('My Monstera'), findsWidgets);
      expect(find.text('Monstera deliciosa'), findsOneWidget);
    });

    testWidgets('fun fact section is hidden when funFact is null',
        (tester) async {
      await tester.pumpWidget(_wrap(
        PlantDetailScreen(
          plantId: 'abc-123',
          getPlant: (_) async => _makePlant(funFact: null),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Fun Fact'), findsNothing);
    });

    testWidgets('fun fact section is shown when funFact is present',
        (tester) async {
      await tester.pumpWidget(_wrap(
        PlantDetailScreen(
          plantId: 'abc-123',
          getPlant: (_) async =>
              _makePlant(funFact: 'Leaves develop holes as they mature.'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Fun Fact'), findsOneWidget);
      expect(
          find.text('Leaves develop holes as they mature.'), findsOneWidget);
    });

    testWidgets('shows error message on fetch failure', (tester) async {
      await tester.pumpWidget(_wrap(
        PlantDetailScreen(
          plantId: 'abc-123',
          getPlant: (_) async =>
              throw const PlantFetchException('Plant not found.', statusCode: 404),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Plant not found.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('delete confirm dialog: cancel does NOT call deletePlant',
        (tester) async {
      bool deleteCalled = false;

      await tester.pumpWidget(_wrap(
        PlantDetailScreen(
          plantId: 'abc-123',
          getPlant: (_) async => _makePlant(),
          deletePlant: (_) async => deleteCalled = true,
        ),
      ));
      await tester.pumpAndSettle();

      // Open the overflow menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap Delete in the menu
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Dialog is shown — tap Cancel
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isFalse);
    });

    testWidgets('delete confirm dialog: confirm DOES call deletePlant and pops',
        (tester) async {
      bool deleteCalled = false;
      bool? poppedWithTrue;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () async {
              poppedWithTrue = await Navigator.of(ctx).push<bool>(
                MaterialPageRoute(
                  builder: (_) => PlantDetailScreen(
                    plantId: 'abc-123',
                    getPlant: (_) async => _makePlant(),
                    deletePlant: (_) async => deleteCalled = true,
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      // Navigate to the detail screen
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Open overflow menu and tap Delete
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirm in dialog
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
      expect(poppedWithTrue, isTrue);
    });
  });
}
