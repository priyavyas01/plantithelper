import 'package:flutter_test/flutter_test.dart';
import 'package:plant_it_helper/models/scan_models.dart';

void main() {
  group('CareInfo.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'light': 'Bright indirect',
        'water': 'Weekly',
        'humidity': 'High',
        'temperature': '18-27°C',
        'tips': ['Wipe leaves', 'Mist occasionally'],
      };
      final care = CareInfo.fromJson(json);
      expect(care.light, 'Bright indirect');
      expect(care.water, 'Weekly');
      expect(care.humidity, 'High');
      expect(care.temperature, '18-27°C');
      expect(care.tips, ['Wipe leaves', 'Mist occasionally']);
    });

    test('parses empty tips list', () {
      final json = {
        'light': 'Low light',
        'water': 'Fortnightly',
        'humidity': 'Low',
        'temperature': '15-25°C',
        'tips': <dynamic>[],
      };
      expect(CareInfo.fromJson(json).tips, isEmpty);
    });
  });

  group('ScanResult.fromJson', () {
    Map<String, dynamic> baseJson({
      String confidence = 'high',
      String? funFact,
    }) =>
        {
          'common_name': 'Monstera',
          'scientific_name': 'Monstera deliciosa',
          'confidence': confidence,
          'care': {
            'light': 'Bright indirect',
            'water': 'Weekly',
            'humidity': 'High',
            'temperature': '18-27°C',
            'tips': ['Wipe leaves'],
          },
          if (funFact != null) 'fun_fact': funFact,
        };

    test('parses all fields', () {
      final result = ScanResult.fromJson(
        baseJson(funFact: 'Leaves can grow huge!'),
      );
      expect(result.commonName, 'Monstera');
      expect(result.scientificName, 'Monstera deliciosa');
      expect(result.confidence, 'high');
      expect(result.care.light, 'Bright indirect');
      expect(result.care.tips, ['Wipe leaves']);
      expect(result.funFact, 'Leaves can grow huge!');
    });

    test('funFact is null when absent from response', () {
      final result = ScanResult.fromJson(baseJson());
      expect(result.funFact, isNull);
    });

    test('parses medium confidence', () {
      final result = ScanResult.fromJson(baseJson(confidence: 'medium'));
      expect(result.confidence, 'medium');
    });

    test('parses low confidence', () {
      final result = ScanResult.fromJson(baseJson(confidence: 'low'));
      expect(result.confidence, 'low');
    });
  });
}
