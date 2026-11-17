import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jamcon/data/providers.dart';

/// Per-device convenience list (kept in local storage only).
class RecentlyViewedNotifier extends Notifier<List<String>> {
  static const _key = 'recent_packages_v1';

  @override
  List<String> build() {
    final raw = ref.read(localStoreProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  void add(String id) {
    final next = [id, ...state.where((x) => x != id)].take(8).toList();
    state = next;
    ref.read(localStoreProvider).setString(_key, jsonEncode(next));
  }
}

final recentlyViewedProvider = NotifierProvider<RecentlyViewedNotifier, List<String>>(RecentlyViewedNotifier.new);
