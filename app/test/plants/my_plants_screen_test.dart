import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_it_helper/models/scan_models.dart';
import 'package:plant_it_helper/screens/plants/my_plants_screen.dart';

// ---------------------------------------------------------------------------
// Test seam
// We can't inject a fake service into MyPlantsScreen directly (it calls
// PlantService.getPlants() statically). Instead we build a testable version
// that accepts a getPlants callback — the same pattern we used for onSave
// in ResultScreen.
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required Future<List<PlantListItem>> Function() getPlants,
}) {
  return MaterialApp(
    routes: {
      '/login': (_) => const Scaffold(body: Text('login')),
    },
    home: _TestableMyPlants(getPlants: getPlants),
  );
}

class _TestableMyPlants extends StatefulWidget {
  final Future<List<PlantListItem>> Function() getPlants;
  const _TestableMyPlants({required this.getPlants});

  @override
  State<_TestableMyPlants> createState() => _TestableMyPlantsState();
}

class _TestableMyPlantsState extends State<_TestableMyPlants> {
  List<PlantListItem> _plants = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final plants = await widget.getPlants();
      if (!mounted) return;
      setState(() {
        _plants = plants;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load plants. Pull to refresh.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Plants')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Try Again')),
        ],
      );
    }
    if (_plants.isEmpty) {
      return const Center(child: Text('You have no plants yet.'));
    }
    return ListView.builder(
      itemCount: _plants.length,
      itemBuilder: (_, i) => PlantCard(plant: _plants[i]),
    );
  }
}

// ---------------------------------------------------------------------------
// Test data factory
// ---------------------------------------------------------------------------

PlantListItem _makePlant({
  String id = 'p1',
  String name = 'My Rose',
  String commonName = 'Rose',
  String scientificName = 'Rosa rubiginosa',
  String confidence = 'high',
  DateTime? createdAt,
}) {
  return PlantListItem(
    id: id,
    name: name,
    commonName: commonName,
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
    testWidgets('shows loading indicator while fetching', (tester) async {
      // A Completer that never completes — simulates an in-flight request.
      final completer = Completer<List<PlantListItem>>();
      await tester.pumpWidget(_buildScreen(getPlants: () => completer.future));
      // pump() advances one frame without settling — loading state is visible.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Clean up so the widget tree doesn't error on teardown.
      completer.complete([]);
    });

    testWidgets('shows empty state when no plants returned', (tester) async {
      await tester.pumpWidget(_buildScreen(getPlants: () async => []));
      await tester.pumpAndSettle();
      expect(find.text('You have no plants yet.'), findsOneWidget);
    });

    testWidgets('renders a PlantCard for each returned plant', (tester) async {
      final plants = [
        _makePlant(id: 'p1', name: 'My Rose', scientificName: 'Rosa rubiginosa'),
        _makePlant(
          id: 'p2',
          name: 'Snake Plant',
          scientificName: 'Sansevieria trifasciata',
        ),
      ];
      await tester.pumpWidget(_buildScreen(getPlants: () async => plants));
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

    testWidgets('does NOT show uncertain-ID badge for high-confidence plant', (tester) async {
      await tester.pumpWidget(
        _buildScreen(getPlants: () async => [_makePlant(confidence: 'high')]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Uncertain ID'), findsNothing);
    });

    testWidgets('shows uncertain-ID badge for low-confidence plant', (tester) async {
      await tester.pumpWidget(
        _buildScreen(getPlants: () async => [_makePlant(confidence: 'low')]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Uncertain ID'), findsOneWidget);
    });

    testWidgets('pull-to-refresh calls service again', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(
        _buildScreen(getPlants: () async {
          callCount++;
          return [_makePlant()];
        }),
      );
      await tester.pumpAndSettle();
      expect(callCount, 1);

      // Fling simulates a pull-down gesture on the ListView.
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
      expect(callCount, 2);
    });
  });
}
