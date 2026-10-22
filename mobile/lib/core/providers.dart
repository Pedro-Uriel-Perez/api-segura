/// Riverpod wiring for shared infrastructure and repositories.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/tasks/data/task_repository.dart';
import 'network/api_client.dart';
import 'storage/token_store.dart';

/// Secure token storage shared by the whole app.
final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore(const FlutterSecureStorage());
});

/// Authenticated API client; a failed refresh signs the user out.
final apiClientProvider = Provider<ApiClient>((ref) {
  final httpClient = http.Client();
  ref.onDispose(httpClient.close);
  return ApiClient(
    httpClient,
    ref.read(tokenStoreProvider),
    onSessionExpired: () => ref.read(authStateProvider.notifier).signOut(),
  );
});

/// Authentication repository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider), ref.read(tokenStoreProvider));
});

/// Task repository.
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(ref.read(apiClientProvider));
});
