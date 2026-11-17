import 'package:shared_preferences/shared_preferences.dart';

/// Thin key/value wrapper over SharedPreferences with an in-memory fallback
/// (private windows, tests). Swap for secure storage when real tokens exist.
class LocalStore {
  LocalStore._(this._prefs);
  final SharedPreferences? _prefs;
  final Map<String, String> _mem = {};

  static Future<LocalStore> open() async {
    try {
      return LocalStore._(await SharedPreferences.getInstance());
    } catch (_) {
      return LocalStore._(null);
    }
  }

  factory LocalStore.memory() => LocalStore._(null);

  String? getString(String key) {
    try {
      return _prefs?.getString(key) ?? _mem[key];
    } catch (_) {
      return _mem[key];
    }
  }

  void setString(String key, String value) {
    _mem[key] = value;
    try {
      _prefs?.setString(key, value);
    } catch (_) {}
  }

  void remove(String key) {
    _mem.remove(key);
    try {
      _prefs?.remove(key);
    } catch (_) {}
  }
}
