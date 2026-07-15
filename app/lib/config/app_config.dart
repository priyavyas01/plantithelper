class AppConfig {
  AppConfig._();

  // Single source of truth for the API base URL.
  // Pass at build time: flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
  // On simulators the default localhost:8000 works fine.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
