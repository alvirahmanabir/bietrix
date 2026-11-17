/// Environment configuration. Override at build time, e.g.
/// `flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://api.studio.com/v1`
abstract final class Env {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.example.com/v1');
  static const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);
  static const appName = String.fromEnvironment('APP_NAME', defaultValue: 'JamCon');
  static const mockLatencyMs = int.fromEnvironment('MOCK_LATENCY_MS', defaultValue: 150);
}
