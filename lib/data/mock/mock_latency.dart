import 'package:jamcon/app/config/env.dart';

/// Simulated network latency (disabled in tests).
abstract final class MockLatency {
  static bool enabled = true;
  static Future<void> wait([int? ms]) async {
    if (!enabled) return;
    await Future<void>.delayed(Duration(milliseconds: ms ?? Env.mockLatencyMs));
  }
}
