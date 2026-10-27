import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user_session_model.dart';
import '../../data/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class UserSessionNotifier extends StateNotifier<AsyncValue<UserSession?>> {
  final AuthService _authService;

  UserSessionNotifier(this._authService) : super(const AsyncValue.loading()) {
    checkSavedSession();
  }

  Future<void> checkSavedSession() async {
    try {
      final session = await _authService.getActiveSession();
      state = AsyncValue.data(session);
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  Future<UserSession> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final session = await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
      if (session.isLoggedIn) {
        state = AsyncValue.data(session);
      }
      return session;
    } catch (_) {
      rethrow;
    }
  }

  Future<UserSession> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final session = await _authService.signIn(email: email, password: password);
      state = AsyncValue.data(session);
      return session;
    } catch (_) {
      rethrow;
    }
  }

  Future<UserSession> verifyOtp({
    required String email,
    required String token,
  }) async {
    try {
      final session = await _authService.verifyOtp(email: email, token: token);
      state = AsyncValue.data(session);
      return session;
    } catch (_) {
      rethrow;
    }
  }

  Future<UserSession> continueAsGuest({String name = 'User'}) async {
    try {
      final session = await _authService.continueAsGuest(name: name);
      state = AsyncValue.data(session);
      return session;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> updateAvatar(String avatarUrl) async {
    final current = state.value;
    if (current != null) {
      final updated = current.copyWith(avatarUrl: avatarUrl);
      state = AsyncValue.data(updated);
      await _authService.saveSession(updated);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _authService.clearSession();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final userSessionProvider =
    StateNotifierProvider<UserSessionNotifier, AsyncValue<UserSession?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return UserSessionNotifier(authService);
});
