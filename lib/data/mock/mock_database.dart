import 'dart:async';
import 'dart:convert';

import 'package:jamcon/core/storage/local_store.dart';
import 'package:jamcon/data/mock/mock_latency.dart';
import 'package:jamcon/data/mock/seed.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/domain/models/coupon.dart';
import 'package:jamcon/domain/models/support.dart';
import 'package:jamcon/domain/models/user.dart';

/// In-memory "server database" shared by every mock service, so customer and admin
/// views stay consistent. Snapshots are persisted to [LocalStore] after each commit.
class MockDatabase {
  MockDatabase._(this.store);
  final LocalStore store;

  static const _key = 'mockdb_v1';

  List<AppUser> users = [];
  List<AdminUser> admins = [];
  List<Service> services = [];
  List<Package> packages = [];
  List<Coupon> coupons = [];
  List<Booking> bookings = [];
  List<SupportRequest> support = [];
  Map<String, List<String>> wishlists = {};
  Map<String, String> passwords = {}; // email -> password (mock only!)
  int _seq = 0;

  // Runtime-only (not persisted)
  final Map<String, AppUser> pendingUsers = {};
  final Map<String, String> pendingPasswords = {};
  final Map<String, String> otps = {};
  static const demoOtp = '123456';

  final StreamController<void> _ticks = StreamController<void>.broadcast();

  static MockDatabase open(LocalStore store) {
    final db = MockDatabase._(store);
    final raw = store.getString(_key);
    var loaded = false;
    if (raw != null) {
      try {
        db._load(jsonDecode(raw) as Map<String, dynamic>);
        loaded = true;
      } catch (_) {
        loaded = false;
      }
    }
    if (!loaded) {
      Seed.populate(db);
      db._persist();
    }
    return db;
  }

  /// Wipes persisted data and re-seeds (used by "Reset demo data").
  void reset() {
    users = [];
    admins = [];
    services = [];
    packages = [];
    coupons = [];
    bookings = [];
    support = [];
    wishlists = {};
    passwords = {};
    _seq = 0;
    Seed.populate(this);
    commit();
  }

  String nextId(String prefix) => '${prefix}_${++_seq}';
  int get seq => _seq;

  void commit() {
    _persist();
    _ticks.add(null);
  }

  /// Emits [read] after simulated latency, then again after every commit.
  Stream<T> watch<T>(T Function() read) async* {
    await MockLatency.wait();
    yield read();
    await for (final _ in _ticks.stream) {
      yield read();
    }
  }

  void _persist() {
    try {
      store.setString(_key, jsonEncode(_toJson()));
    } catch (_) {}
  }

  Map<String, dynamic> _toJson() => {
        'seq': _seq,
        'users': users.map((e) => e.toJson()).toList(),
        'admins': admins.map((e) => e.toJson()).toList(),
        'services': services.map((e) => e.toJson()).toList(),
        'packages': packages.map((e) => e.toJson()).toList(),
        'coupons': coupons.map((e) => e.toJson()).toList(),
        'bookings': bookings.map((e) => e.toJson()).toList(),
        'support': support.map((e) => e.toJson()).toList(),
        'wishlists': wishlists,
        'passwords': passwords,
      };

  List<Map<String, dynamic>> _list(dynamic v) => (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  void _load(Map<String, dynamic> j) {
    _seq = j['seq'] as int;
    users = _list(j['users']).map(AppUser.fromJson).toList();
    admins = _list(j['admins']).map(AdminUser.fromJson).toList();
    services = _list(j['services']).map(Service.fromJson).toList();
    packages = _list(j['packages']).map(Package.fromJson).toList();
    coupons = _list(j['coupons']).map(Coupon.fromJson).toList();
    bookings = _list(j['bookings']).map(Booking.fromJson).toList();
    support = _list(j['support']).map(SupportRequest.fromJson).toList();
    wishlists = {for (final e in (j['wishlists'] as Map).entries) e.key as String: (e.value as List).cast<String>()};
    passwords = Map<String, String>.from(j['passwords'] as Map);
  }
}
