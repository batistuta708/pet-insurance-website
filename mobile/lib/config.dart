import 'package:flutter/foundation.dart' show kReleaseMode;

/// Live server on Render, used by release builds (what goes to Google Play).
const String productionApiUrl = 'https://pet-insurance.onrender.com/api/v1';

/// Flask on your computer as seen from the Android emulator (10.0.2.2 = the host machine),
/// used by `flutter run` during development.
const String developmentApiUrl = 'http://10.0.2.2:5000/api/v1';

const String _override = String.fromEnvironment('API_BASE_URL');

/// Base URL of the Flask JSON API.
///
/// - Release builds use [productionApiUrl]; debug builds use [developmentApiUrl].
/// - Override either with: --dart-define=API_BASE_URL=https://.../api/v1
const String apiBaseUrl =
    _override != '' ? _override : (kReleaseMode ? productionApiUrl : developmentApiUrl);
