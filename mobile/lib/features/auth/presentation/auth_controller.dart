/// Holds the signed-in / signed-out application state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// Session state of the application.
enum AuthStatus {
  /// Checking secure storage on startup.
  unknown,

  /// A token pair is stored.
  signedIn,

  /// No session; the login screen is shown.
  signedOut,
}

/// Drives navigation between the login screen and the task list.
class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    _restore();
    return AuthStatus.unknown;
  }

  Future<void> _restore() async {
    final hasSession = await ref.read(authRepositoryProvider).hasSession();
    state = hasSession ? AuthStatus.signedIn : AuthStatus.signedOut;
  }

  /// Logs in; throws an ApiException with a safe message on failure.
  Future<void> login(String email, String password) async {
    await ref.read(authRepositoryProvider).login(email, password);
    state = AuthStatus.signedIn;
  }

  /// Registers; throws an ApiException with a safe message on failure.
  Future<void> register(String email, String password) async {
    await ref.read(authRepositoryProvider).register(email, password);
    state = AuthStatus.signedIn;
  }

  /// Revokes the session on the server (best effort) and clears local tokens.
  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = AuthStatus.signedOut;
  }

  /// Marks the session as ended after tokens were already cleared.
  void signOut() => state = AuthStatus.signedOut;
}

/// Application session state.
final authStateProvider =
    NotifierProvider<AuthController, AuthStatus>(AuthController.new);
