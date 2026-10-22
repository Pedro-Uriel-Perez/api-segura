/// Verifies refresh-and-retry behavior and safe errors of ApiClient.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';

import 'fakes.dart';

const _base = 'http://test.local/api/v1';

void main() {
  test('refreshes once on 401 and retries the original request once', () async {
    var originalCalls = 0;
    var refreshCalls = 0;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        refreshCalls++;
        expect(jsonDecode(request.body)['refreshToken'], 'old-refresh');
        return http.Response(jsonEncode({
          'accessToken': 'new-access',
          'refreshToken': 'new-refresh',
        }), 200);
      }
      originalCalls++;
      if (originalCalls == 1) {
        expect(request.headers['authorization'], 'Bearer old-access');
        return http.Response('{}', 401);
      }
      expect(request.headers['authorization'], 'Bearer new-access');
      return http.Response(jsonEncode({'items': []}), 200);
    });
    final tokens = FakeTokenStore(
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
    );
    final client = ApiClient(mock, tokens, baseUrl: _base);

    await client.send('GET', 'tasks');

    expect(refreshCalls, 1);
    expect(originalCalls, 2);
    expect(tokens.savedAccessToken, 'new-access');
    expect(tokens.savedRefreshToken, 'new-refresh');
  });

  test('concurrent 401s share a single refresh request', () async {
    var refreshCalls = 0;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(jsonEncode({
          'accessToken': 'new-access',
          'refreshToken': 'new-refresh',
        }), 200);
      }
      if (request.headers['authorization'] == 'Bearer old-access') {
        return http.Response('{}', 401);
      }
      return http.Response(jsonEncode({'items': []}), 200);
    });
    final tokens = FakeTokenStore(accessToken: 'old-access', refreshToken: 'old-refresh');
    final client = ApiClient(mock, tokens, baseUrl: _base);

    await Future.wait([
      client.send('GET', 'tasks'),
      client.send('GET', 'tasks'),
      client.send('GET', 'tasks'),
    ]);

    expect(refreshCalls, 1);
  });

  test('failed refresh clears tokens and signals session expiry', () async {
    var expired = false;
    final mock = MockClient((request) async => http.Response('{}', 401));
    final tokens = FakeTokenStore(accessToken: 'a', refreshToken: 'r');
    final client = ApiClient(
      mock,
      tokens,
      baseUrl: _base,
      onSessionExpired: () => expired = true,
    );

    await expectLater(
      client.send('GET', 'tasks'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(tokens.cleared, isTrue);
    expect(expired, isTrue);
  });

  test('auth paths never trigger a refresh', () async {
    var calls = 0;
    final mock = MockClient((request) async {
      calls++;
      return http.Response('{}', 401);
    });
    final client = ApiClient(mock, FakeTokenStore(), baseUrl: _base);

    await expectLater(
      client.send('POST', 'auth/login', body: {'email': 'a@b.c', 'password': 'x'}),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'Invalid email or password.')),
    );
    expect(calls, 1);
  });

  test('errors never contain tokens or raw server bodies', () async {
    final mock = MockClient((request) async => http.Response(
          '{"error":{"message":"PrismaClientKnownRequestError at secret-table"}}',
          500,
        ));
    final client = ApiClient(
      mock,
      FakeTokenStore(accessToken: 'super-secret-access'),
      baseUrl: _base,
    );

    try {
      await client.send('GET', 'tasks');
      fail('Expected ApiException');
    } on ApiException catch (e) {
      expect(e.statusCode, 500);
      expect(e.toString(), isNot(contains('Prisma')));
      expect(e.toString(), isNot(contains('super-secret-access')));
    }
  });

  test('network failures become a safe connection message', () async {
    final mock = MockClient((request) async => throw const SocketLikeException());
    final client = ApiClient(mock, FakeTokenStore(), baseUrl: _base);

    await expectLater(
      client.send('GET', 'tasks'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', contains('Could not connect'))),
    );
  });

  test('requests that never answer time out with a safe message', () async {
    final mock = MockClient((request) => Completer<http.Response>().future);
    final client = ApiClient(mock, FakeTokenStore(), baseUrl: _base);

    await expectLater(
      client.send('GET', 'tasks'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', contains('Could not connect'))),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('malformed JSON becomes a safe message', () async {
    final mock = MockClient((request) async => http.Response('<html>oops', 200));
    final client = ApiClient(mock, FakeTokenStore(), baseUrl: _base);

    await expectLater(
      client.send('GET', 'tasks'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'The server returned unexpected data.')),
    );
  });

  test('keeps the query string when building URLs', () async {
    late Uri seen;
    final mock = MockClient((request) async {
      seen = request.url;
      return http.Response(jsonEncode({'items': []}), 200);
    });
    final client = ApiClient(mock, FakeTokenStore(), baseUrl: _base);

    await client.send('GET', 'tasks?page=2&limit=5');

    expect(seen.path, '/api/v1/tasks');
    expect(seen.queryParameters, {'page': '2', 'limit': '5'});
  });
}

/// Simulates a transport failure.
class SocketLikeException implements Exception {
  const SocketLikeException();
}
