/// Keeps the task list state outside the widget tree.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../domain/task.dart';

/// Loads and mutates the signed-in user's tasks.
class TaskController extends AutoDisposeAsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() => ref.read(taskRepositoryProvider).list();

  /// Reloads the list, showing the loading state.
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(taskRepositoryProvider).list());
  }

  /// Creates a task and prepends it to the list.
  Future<void> add(String title, String? description) async {
    final task = await ref.read(taskRepositoryProvider).create(title, description);
    state = AsyncData([task, ...state.valueOrNull ?? []]);
  }

  /// Edits a task's title and description.
  Future<void> edit(Task task, String title, String? description) async {
    final updated = await ref.read(taskRepositoryProvider).edit(task, title, description);
    _replace(updated);
  }

  /// Toggles a task's completion state.
  Future<void> toggle(Task task) async {
    final updated =
        await ref.read(taskRepositoryProvider).setCompleted(task, !task.completed);
    _replace(updated);
  }

  /// Deletes a task.
  Future<void> delete(Task task) async {
    await ref.read(taskRepositoryProvider).delete(task.id);
    state = AsyncData([
      for (final t in state.valueOrNull ?? <Task>[])
        if (t.id != task.id) t,
    ]);
  }

  void _replace(Task updated) {
    state = AsyncData([
      for (final t in state.valueOrNull ?? <Task>[]) t.id == updated.id ? updated : t,
    ]);
  }
}

/// The signed-in user's tasks.
final tasksProvider =
    AsyncNotifierProvider.autoDispose<TaskController, List<Task>>(TaskController.new);
