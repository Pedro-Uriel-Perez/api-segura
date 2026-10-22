/// Test doubles shared by the client tests.
library;

import 'package:mobile/core/storage/token_store.dart';

/// In-memory token store that records saved and cleared tokens.
class FakeTokenStore implements TokenStore {
  /// Creates a fake store holding an initial token pair.
  FakeTokenStore({this.accessToken, this.refreshToken});

  /// Current access token.
  String? accessToken;

  /// Current refresh token.
  String? refreshToken;

  /// Last access token passed to [saveTokens].
  String? savedAccessToken;

  /// Last refresh token passed to [saveTokens].
  String? savedRefreshToken;

  /// Whether [clear] was called.
  bool cleared = false;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    this.accessToken = savedAccessToken = accessToken;
    this.refreshToken = savedRefreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    cleared = true;
  }
}
