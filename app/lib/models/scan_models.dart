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
/// [scanCount] drives whether the scan history section is shown (visible when > 1).
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
  final int scanCount;

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
    required this.scanCount,
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
        scanCount: json['scan_count'] as int? ?? 1,
      );
}

/// Request body for POST /plants/{id}/scans — add a scan to an existing plant.
/// Same fields as [SavePlantRequest] minus the plant name (plant already exists).
class AddScanRequest {
  final String commonName;
  final String scientificName;
  final String confidence;
  final String health;
  final String healthObservation;
  final CareInfo care;
  final String? funFact;

  const AddScanRequest({
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    required this.health,
    required this.healthObservation,
    required this.care,
    this.funFact,
  });

  Map<String, dynamic> toJson() => {
        'common_name': commonName,
        'scientific_name': scientificName,
        'confidence': confidence,
        'health': health,
        'health_observation': healthObservation,
        'care': care.toJson(),
        if (funFact != null) 'fun_fact': funFact,
      };
}

/// One row in the GET /plants/{id}/scans history list.
class PlantScanItem {
  final String id;
  final String commonName;
  final String health;
  final String healthObservation;
  final DateTime scannedAt;

  const PlantScanItem({
    required this.id,
    required this.commonName,
    required this.health,
    required this.healthObservation,
    required this.scannedAt,
  });

  factory PlantScanItem.fromJson(Map<String, dynamic> json) => PlantScanItem(
        id: json['id'] as String,
        commonName: json['common_name'] as String,
        health: json['health'] as String? ?? 'unknown',
        healthObservation: json['health_observation'] as String? ?? '',
        scannedAt: DateTime.parse(json['scanned_at'] as String),
      );
}
