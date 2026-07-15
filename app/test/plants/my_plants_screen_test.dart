import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_it_helper/models/scan_models.dart';
import 'package:plant_it_helper/screens/plants/my_plants_screen.dart';
import 'package:plant_it_helper/services/plant_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required Future<PlantListResult> Function() getPlants,
}) {
  return MaterialApp(
    routes: {'/login': (_) => const Scaffold(body: Text('login'))},
    home: MyPlantsScreen(getPlants: getPlants),
  );
}

PlantListItem _makePlant({
  String id = 'p1',
  String name = 'My Rose',
  String scientificName = 'Rosa rubiginosa',
  String confidence = 'high',
  DateTime? createdAt,
}) {
  return PlantListItem(
    id: id,
    name: name,
    commonName: 'Rose',
    scientificName: scientificName,
    confidence: confidence,
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(days: 3)),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MyPlantsScreen', () {
    testWidgets('shows loading skeleton while fetching', (tester) async {
      final completer = Completer<PlantListResult>();
      await tester.pumpWidget(
        _buildScreen(getPlants: () => completer.future),
      );
      await tester.pump();
      expect(find.byKey(const Key('loading_skeleton')), findsOneWidget);
      expect(find.byType(PlantCard), findsNothing);
      completer.complete(PlantListResult([]));
    });

    testWidgets('shows empty state when no plants returned', (tester) async {
      await tester.pumpWidget(
        _buildScreen(getPlants: () async => PlantListResult([])),
      );
      await tester.pumpAndSettle();
      expect(find.text('You have no plants yet.'), findsOneWidget);
    });

    testWidgets('renders a PlantCard for each returned plant', (tester) async {
      final plants = [
        _makePlant(id: 'p1', name: 'My Rose', scientificName: 'Rosa rubiginosa'),
        _makePlant(id: 'p2', name: 'Snake Plant', scientificName: 'Sansevieria trifasciata'),
      ];
      await tester.pumpWidget(
        _buildScreen(getPlants: () async => PlantListResult(plants)),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Rose'), findsOneWidget);
      expect(find.text('Rosa rubiginosa'), findsOneWidget);
      expect(find.text('Snake Plant'), findsOneWidget);
      expect(find.text('Sansevieria trifasciata'), findsOneWidget);
    });

    testWidgets('shows error message when service throws', (tester) async {
      await tester.pumpWidget(
        _buildScreen(getPlants: () async => throw Exception('network error')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Could not load plants. Pull to refresh.'), findsOneWidget);
    });

    testWidgets('shows uncertain-ID badge only for low-confidence plant', (tester) async {
      await tester.pumpWidget(
        _buildScreen(getPlants: () async => PlantListResult([_makePlant(confidence: 'low')])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Uncertain ID'), findsOneWidget);
    });

    testWidgets('does not show uncertain-ID badge for high-confidence plant', (tester) async {
      await tester.pumpWidget(
        _buildScreen(getPlants: () async => PlantListResult([_makePlant(confidence: 'high')])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Uncertain ID'), findsNothing);
    });

    testWidgets('pull-to-refresh calls service again', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(
        _buildScreen(getPlants: () async {
          callCount++;
          return PlantListResult([_makePlant()]);
        }),
      );
      await tester.pumpAndSettle();
      expect(callCount, 1);

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
      expect(callCount, 2);
    });

    // ----- cache banner tests ------------------------------------------------

    testWidgets('shows cache banner when result is fromCache=true', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          getPlants: () async => PlantListResult(
            [_makePlant()],
            fromCache: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Could not refresh. Showing last saved data.'),
        findsOneWidget,
      );
    });

    testWidgets('does not show cache banner when result is fresh', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          getPlants: () async => PlantListResult([_makePlant()]),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Could not refresh. Showing last saved data.'),
        findsNothing,
      );
    });

    testWidgets('still shows plant cards alongside cache banner', (tester) async {
      final plants = [
        _makePlant(id: 'p1', name: 'Cached Rose'),
        _makePlant(id: 'p2', name: 'Cached Fern'),
      ];
      await tester.pumpWidget(
        _buildScreen(
          getPlants: () async => PlantListResult(plants, fromCache: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not refresh. Showing last saved data.'), findsOneWidget);
      expect(find.text('Cached Rose'), findsOneWidget);
      expect(find.text('Cached Fern'), findsOneWidget);
    });
  });
}
