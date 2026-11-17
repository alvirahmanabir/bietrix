import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jamcon/data/providers.dart';
import 'package:jamcon/domain/models/user.dart';
import 'package:jamcon/features/customer/booking/booking_draft.dart';

class SessionNotifier extends Notifier<Session?> {
  @override
  Session? build() => ref.read(authServiceProvider).restore();

  Future<void> login(String email, String password, {bool asAdmin = false}) async {
    state = await ref.read(authServiceProvider).login(email: email, password: password, asAdmin: asAdmin);
  }

  Future<void> verifyOtp(String email, String code) async {
    state = await ref.read(authServiceProvider).verifyOtp(email: email, code: code);
  }

  Future<void> logout() async {
    await ref.read(authServiceProvider).logout();
    ref.read(bookingDraftProvider.notifier).clear();
    state = null;
  }

  /// Clears the local session after the account was deleted server-side.
  Future<void> endSessionAfterDeletion() => logout();
}

final sessionProvider = NotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);
