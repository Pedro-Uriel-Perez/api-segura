/// Entry point of the Secure Task Manager client.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/tasks/presentation/task_page.dart';

void main() {
  runApp(const ProviderScope(child: SecureTaskApp()));
}

/// Root widget; switches between login and tasks based on session state.
class SecureTaskApp extends ConsumerWidget {
  /// Creates the app.
  const SecureTaskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authStateProvider);
    return MaterialApp(
      title: 'Secure Task Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: switch (status) {
        AuthStatus.unknown => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        AuthStatus.signedIn => const TaskPage(),
        AuthStatus.signedOut => const LoginPage(),
      },
    );
  }
}
