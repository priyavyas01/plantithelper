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
}

class ScanResult {
  final String commonName;
  final String scientificName;
  // 'high' | 'medium' | 'low' — drives badge colour in the UI
  final String confidence;
  final CareInfo care;
  final String? funFact;

  const ScanResult({
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    required this.care,
    this.funFact,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        commonName: json['common_name'] as String,
        scientificName: json['scientific_name'] as String,
        confidence: json['confidence'] as String,
        care: CareInfo.fromJson(json['care'] as Map<String, dynamic>),
        funFact: json['fun_fact'] as String?,
      );
}
