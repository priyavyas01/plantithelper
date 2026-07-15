import 'package:flutter_test/flutter_test.dart';
import 'package:plant_it_helper/models/scan_models.dart';
import 'package:plant_it_helper/services/plant_service.dart';

// ---------------------------------------------------------------------------
// PlantService cache unit tests
//
// What we test here:
//   - PlantListResult model behaviour (fromCache flag, plants list)
//   - Exception classes (message, statusCode, toString)
//   - PlantService.clearCache() resets state without crashing
//
// What we do NOT test here:
//   - HTTP fallback to cache on network failure — tested in my_plants_screen_test
//     via the injectable getPlants callback. Testing it at the service level
//     would require seeding flutter_secure_storage, which is not available in
//     unit tests (it uses platform channels that need a running app).
// ---------------------------------------------------------------------------

void main() {
  // TestWidgetsFlutterBinding is required because clearCache() calls debugPrint,
  // which goes through the Flutter foundation binding.
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(PlantService.clearCache);

  // -------------------------------------------------------------------------
  // PlantListResult
  // -------------------------------------------------------------------------

  group('PlantListResult', () {
    test('fromCache defaults to false', () {
      final result = PlantListResult([]);
      expect(result.fromCache, isFalse);
    });

    test('fromCache is true when explicitly set', () {
      final result = PlantListResult([], fromCache: true);
      expect(result.fromCache, isTrue);
    });

    test('exposes the plants list', () {
      final plant = _makePlant();
      final result = PlantListResult([plant]);
      expect(result.plants, hasLength(1));
      expect(result.plants.first.id, 'p1');
    });

    test('empty plants list is valid', () {
      expect(PlantListResult([]).plants, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Exception classes
  // -------------------------------------------------------------------------

  group('PlantFetchException', () {
    test('toString returns message', () {
      const ex = PlantFetchException('Session expired.', statusCode: 401);
      expect(ex.toString(), 'Session expired.');
    });

    test('statusCode is accessible', () {
      const ex = PlantFetchException('Not found', statusCode: 404);
      expect(ex.statusCode, 404);
    });

    test('statusCode is nullable', () {
      const ex = PlantFetchException('Network error');
      expect(ex.statusCode, isNull);
    });
  });

  group('PlantSaveException', () {
    test('toString returns message', () {
      const ex = PlantSaveException('Not authenticated', statusCode: 401);
      expect(ex.toString(), 'Not authenticated');
    });

    test('statusCode is accessible', () {
      const ex = PlantSaveException('Invalid data', statusCode: 422);
      expect(ex.statusCode, 422);
    });
  });

  // -------------------------------------------------------------------------
  // clearCache
  // -------------------------------------------------------------------------

  group('PlantService.clearCache', () {
    test('can be called multiple times without error', () {
      expect(PlantService.clearCache, returnsNormally);
      expect(PlantService.clearCache, returnsNormally);
    });
  });
}

// ---------------------------------------------------------------------------
// Test data factory
// ---------------------------------------------------------------------------

PlantListItem _makePlant() => PlantListItem(
      id: 'p1',
      name: 'My Rose',
      commonName: 'Rose',
      scientificName: 'Rosa rubiginosa',
      confidence: 'high',
      health: 'healthy',
      healthObservation: 'Leaves look vibrant and full.',
      createdAt: DateTime.now(),
    );
