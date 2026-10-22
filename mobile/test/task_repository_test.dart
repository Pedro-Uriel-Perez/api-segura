/// Verifies JSON parsing in TaskRepository.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/tasks/data/task_repository.dart';

import 'fakes.dart';

TaskRepository _repo(MockClient mock) => TaskRepository(
      ApiClient(mock, FakeTokenStore(accessToken: 'a'), baseUrl: 'http://t/api/v1'),
    );

void main() {
  test('parses a successful task list', () async {
    final repo = _repo(MockClient((request) async => http.Response(
          jsonEncode({
            'items': [
              {'id': 'c1', 'title': 'One', 'description': null, 'completed': false},
              {'id': 'c2', 'title': 'Two', 'description': 'Details', 'completed': true},
            ],
            'page': 1,
            'limit': 20,
          }),
          200,
        )));

    final tasks = await repo.list();

    expect(tasks, hasLength(2));
    expect(tasks.first.title, 'One');
    expect(tasks.last.description, 'Details');
    expect(tasks.last.completed, isTrue);
  });

  test('returns an empty list', () async {
    final repo = _repo(MockClient(
      (request) async => http.Response(jsonEncode({'items': []}), 200),
    ));
    expect(await repo.list(), isEmpty);
  });

  test('never sends an owner id when creating a task', () async {
    late Map<String, dynamic> sent;
    final repo = _repo(MockClient((request) async {
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'item': {'id': 'c1', 'title': 'New', 'description': null, 'completed': false},
        }),
        201,
      );
    }));

    await repo.create('  New  ', '   ');

    expect(sent.keys, unorderedEquals(['title', 'description']));
    expect(sent['title'], 'New');
    expect(sent['description'], isNull);
  });
}
