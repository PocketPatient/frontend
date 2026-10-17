import 'package:flutter/foundation.dart' show kReleaseMode;

// Production backend (Cloud Run, GCP project the-pocket-patient).
const String _kProdApiBaseUrl =
    'https://pocket-patient-api-oigghutrva-ue.a.run.app/api/v1';
// Local dev: 10.0.2.2 is the Android emulator's alias for the host machine
// (use http://localhost:8000/api/v1 for the iOS simulator, or your LAN IP on a
// physical device).
const String _kDevApiBaseUrl = 'http://10.0.2.2:8000/api/v1';

// Release builds (App Store / TestFlight) always default to production; override
// any build with --dart-define=API_BASE_URL=<url>.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: kReleaseMode ? _kProdApiBaseUrl : _kDevApiBaseUrl,
);
const String kAppName = 'Pocket Patient';
const String kTokenKey = 'auth_token';
const String kRefreshTokenKey = 'refresh_token';
const String kUserIdKey = 'auth_user_id';
