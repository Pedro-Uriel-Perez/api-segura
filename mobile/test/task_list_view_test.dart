/// Widget tests for loading, empty, error, and populated task-list states.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/tasks/domain/task.dart';
import 'package:mobile/features/tasks/presentation/task_list_view.dart';

Widget _wrap({
  bool loading = false,
  List<Task> tasks = const [],
  String? error,
  VoidCallback? onRetry,
  ValueChanged<Task>? onToggle,
  ValueChanged<Task>? onDelete,
}) {
  return MaterialApp(
    home: Scaffold(
      body: TaskListView(
        loading: loading,
        tasks: tasks,
        errorMessage: error,
        onRetry: onRetry ?? () {},
        onToggle: onToggle ?? (_) {},
        onDelete: onDelete ?? (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('shows a spinner while loading', (tester) async {
    await tester.pumpWidget(_wrap(loading: true));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the empty state', (tester) async {
    await tester.pumpWidget(_wrap());
    expect(find.text('No tasks yet. Add your first task.'), findsOneWidget);
  });

  testWidgets('shows the error with a working retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(error: 'Could not connect', onRetry: () => retried = true));
    expect(find.text('Could not connect'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('renders tasks and forwards toggle and delete', (tester) async {
    const task = Task(id: 'c1', title: 'Buy milk', description: 'Whole', completed: false);
    Task? toggled;
    Task? deleted;
    await tester.pumpWidget(_wrap(
      tasks: const [task],
      onToggle: (t) => toggled = t,
      onDelete: (t) => deleted = t,
    ));

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Whole'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.byTooltip('Delete task'));
    expect(toggled?.id, 'c1');
    expect(deleted?.id, 'c1');
  });
}
