/// Task list screen with create, edit, toggle and delete actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/task.dart';
import 'task_controller.dart';
import 'task_list_view.dart';

/// Shows the signed-in user's tasks.
class TaskPage extends ConsumerWidget {
  /// Creates the task page.
  const TaskPage({super.key});

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref, {Task? task}) async {
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => _TaskFormDialog(task: task),
    );
    if (result == null || !context.mounted) return;
    final controller = ref.read(tasksProvider.notifier);
    await _run(
      context,
      () => task == null
          ? controller.add(result.$1, result.$2)
          : controller.edit(task, result.$1, result.$2),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _run(context, () => ref.read(tasksProvider.notifier).delete(task));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final error = tasks.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My tasks'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(tasksProvider.notifier).reload(),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
          ),
        ],
      ),
      body: TaskListView(
        loading: tasks.isLoading,
        tasks: tasks.valueOrNull ?? const [],
        errorMessage: error == null
            ? null
            : (error is ApiException ? error.message : 'Something went wrong.'),
        onRetry: () => ref.read(tasksProvider.notifier).reload(),
        onToggle: (task) => _run(context, () => ref.read(tasksProvider.notifier).toggle(task)),
        onDelete: (task) => _confirmDelete(context, ref, task),
        onEdit: (task) => _openForm(context, ref, task: task),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
    );
  }
}

/// Validated create/edit form for a task.
class _TaskFormDialog extends StatefulWidget {
  const _TaskFormDialog({this.task});

  final Task? task;

  @override
  State<_TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<_TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _description = TextEditingController(text: widget.task?.description);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? 'New task' : 'Edit task'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _title,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required.' : null,
            ),
            TextFormField(
              controller: _description,
              maxLength: 2000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, (_title.text, _description.text));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
