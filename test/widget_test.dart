import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jamcon/app/app.dart';
import 'package:jamcon/core/storage/local_store.dart';
import 'package:jamcon/data/mock/mock_latency.dart';
import 'package:jamcon/data/providers.dart';

void main() {
  testWidgets('app boots to the welcome screen for guests', (tester) async {
    MockLatency.enabled = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(LocalStore.memory())],
      child: const JamConApp(),
    ));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
  });
}
