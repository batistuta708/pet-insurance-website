/// Base URL of the Flask JSON API.
///
/// Default points at a Flask server on your computer as seen from the Android
/// emulator (10.0.2.2 = the host machine). Override it for real devices or
/// production builds:
///
///   flutter run --dart-define=API_BASE_URL=https://your-domain.com/api/v1
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:5000/api/v1',
);
