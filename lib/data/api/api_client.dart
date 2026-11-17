import 'package:jamcon/app/config/env.dart';

/// Placeholder for the real HTTP client. When the backend exists:
///  1. add `dio` (or `http`), attach the bearer token + refresh logic here;
///  2. implement `ApiAuthService`, `ApiBookingService`, ... in this folder
///     (they implement the interfaces in `domain/services/services.dart`);
///  3. switch the providers in `data/providers.dart` (`Env.useMock == false`).
/// See docs/BACKEND_INTEGRATION.md for the endpoint map.
class ApiClient {
  const ApiClient({this.baseUrl = Env.apiBaseUrl});
  final String baseUrl;
}
