class CareInfo {
  final String light;
  final String water;
  final String humidity;
  final String temperature;
  final List<String> tips;

  const CareInfo({
    required this.light,
    required this.water,
    required this.humidity,
    required this.temperature,
    required this.tips,
  });

  factory CareInfo.fromJson(Map<String, dynamic> json) => CareInfo(
        light: json['light'] as String,
        water: json['water'] as String,
        humidity: json['humidity'] as String,
        temperature: json['temperature'] as String,
        tips: (json['tips'] as List<dynamic>).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'light': light,
        'water': water,
        'humidity': humidity,
        'temperature': temperature,
        'tips': tips,
      };
}

class ScanResult {
  final String commonName;
  final String scientificName;
  // confidence kept for debugging but not shown in UI — health is user-facing
  final String confidence;
  // 'healthy' | 'needs_attention' | 'concerning' | 'unknown'
  final String health;
  final String healthObservation;
  final CareInfo care;
  final String? funFact;

  const ScanResult({
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    required this.health,
    required this.healthObservation,
    required this.care,
    this.funFact,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        commonName: json['common_name'] as String,
        scientificName: json['scientific_name'] as String,
        confidence: json['confidence'] as String,
        health: json['health'] as String? ?? 'unknown',
        healthObservation: json['health_observation'] as String? ?? '',
        care: CareInfo.fromJson(json['care'] as Map<String, dynamic>),
        funFact: json['fun_fact'] as String?,
      );
}

/// Request body for POST /plants
class SavePlantRequest {
  final String name;
  final String commonName;
  final String scientificName;
  final String confidence;
  final String health;
  final String healthObservation;
  final CareInfo care;
  final String? funFact;

  const SavePlantRequest({
    required this.name,
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    required this.health,
    required this.healthObservation,
    required this.care,
    this.funFact,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'common_name': commonName,
        'scientific_name': scientificName,
        'confidence': confidence,
        'health': health,
        'health_observation': healthObservation,
        'care': care.toJson(),
        if (funFact != null) 'fun_fact': funFact,
      };
}

/// Response from POST /plants (201 Created)
class SavedPlant {
  final String id;
  final String name;
  final DateTime createdAt;

  const SavedPlant({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory SavedPlant.fromJson(Map<String, dynamic> json) => SavedPlant(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// One item in the GET /plants list — summary only, no care JSON.
/// The full care guide comes when you open the detail screen.
class PlantListItem {
  final String id;
  final String name;
  final String commonName;
  final String scientificName;
  final String confidence;
  final String health;
  final String healthObservation;
  final DateTime createdAt;

  const PlantListItem({
    required this.id,
    required this.name,
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    required this.health,
    required this.healthObservation,
    required this.createdAt,
  });

  factory PlantListItem.fromJson(Map<String, dynamic> json) => PlantListItem(
        id: json['id'] as String,
        name: json['name'] as String,
        commonName: json['common_name'] as String,
        scientificName: json['scientific_name'] as String,
        confidence: json['confidence'] as String,
        health: json['health'] as String? ?? 'unknown',
        healthObservation: json['health_observation'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Full plant data returned by GET /plants/{id}.
/// Includes the complete care guide — only fetch this when opening detail.
class PlantDetail {
  final String id;
  final String name;
  final String commonName;
  final String scientificName;
  final String confidence;
  final String health;
  final String healthObservation;
  final CareInfo care;
  final String? funFact;
  final DateTime createdAt;

  const PlantDetail({
    required this.id,
    required this.name,
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    required this.health,
    required this.healthObservation,
    required this.care,
    this.funFact,
    required this.createdAt,
  });

  factory PlantDetail.fromJson(Map<String, dynamic> json) => PlantDetail(
        id: json['id'] as String,
        name: json['name'] as String,
        commonName: json['common_name'] as String,
        scientificName: json['scientific_name'] as String,
        confidence: json['confidence'] as String,
        health: json['health'] as String? ?? 'unknown',
        healthObservation: json['health_observation'] as String? ?? '',
        care: CareInfo.fromJson(json['care'] as Map<String, dynamic>),
        funFact: json['fun_fact'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
