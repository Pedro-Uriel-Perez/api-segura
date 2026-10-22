/// End-to-end check: the app's repositories against the real local API.
///
/// Requires the backend running on localhost:3000. Run with:
///   flutter test test_e2e --dart-define=E2E_BASE_URL=http://localhost:3000/api/v1
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/auth/data/auth_repository.dart';
import 'package:mobile/features/tasks/data/task_repository.dart';

import '../test/fakes.dart';

const _base = String.fromEnvironment(
  'E2E_BASE_URL',
  defaultValue: 'http://localhost:3000/api/v1',
);

void main() {
  test('register, CRUD tasks, refresh after expiry, logout', () async {
    final httpClient = http.Client();
    final tokens = FakeTokenStore();
    var sessionExpired = false;
    final api = ApiClient(httpClient, tokens,
        baseUrl: _base, onSessionExpired: () => sessionExpired = true);
    final auth = AuthRepository(api, tokens);
    final repo = TaskRepository(api);
    final email = 'flutter-e2e-${Random().nextInt(1 << 31)}@example.test';
    const password = 'a-long-flutter-e2e-password';

    await auth.register(email, password);
    expect(await tokens.readRefreshToken(), isNotNull);

    expect(await repo.list(), isEmpty);
    final task = await repo.create('From Flutter', 'Created by the E2E test');
    final toggled = await repo.setCompleted(task, true);
    expect(toggled.completed, isTrue);
    final edited = await repo.edit(toggled, 'Edited from Flutter', null);
    expect(edited.title, 'Edited from Flutter');
    expect((await repo.list()).single.id, task.id);

    // Simulate an expired access token: the client must refresh and retry once.
    final oldRefresh = tokens.refreshToken;
    tokens.accessToken = 'expired-or-invalid';
    expect(await repo.list(), hasLength(1));
    expect(tokens.refreshToken, isNot(oldRefresh));

    await repo.delete(task.id);
    expect(await repo.list(), isEmpty);

    // Logout revokes server-side and clears local storage.
    final refreshBeforeLogout = tokens.refreshToken!;
    await auth.logout();
    expect(tokens.cleared, isTrue);
    final reuse = await httpClient.post(
      Uri.parse('$_base/auth/refresh'),
      headers: {'content-type': 'application/json'},
      body: '{"refreshToken":"$refreshBeforeLogout"}',
    );
    expect(reuse.statusCode, 401);

    // With no tokens left, a protected call ends the session.
    await expectLater(repo.list(), throwsA(isA<ApiException>()));
    expect(sessionExpired, isTrue);

    // Wrong credentials give the generic message.
    await expectLater(
      auth.login(email, 'definitely-wrong-password'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'Invalid email or password.')),
    );

    httpClient.close();
  });
}
