// dart | lib/presentation/screens/user_detail_screen.dart | flutter | edit user, view assigned tasks
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/providers.dart';
import '../../repository/exceptions.dart';
import '../widgets/task_tile.dart';

class UserDetailScreen extends ConsumerWidget {
  final int userId;
  const UserDetailScreen({super.key, required this.userId});

  Future<void> _edit(BuildContext context, WidgetRef ref, User user) async {
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать пользователя'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Имя')),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(userRepositoryProvider).update(
            user.copyWith(name: nameCtrl.text.trim(), email: emailCtrl.text.trim()),
          );
    } on DomainException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final tasksAsync = ref.watch(tasksForUserProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользователь'),
        actions: [
          usersAsync.when(
            data: (users) {
              final matches = users.where((u) => u.id == userId).toList();
              if (matches.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _edit(context, ref, matches.first),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              try {
                await ref.read(userRepositoryProvider).delete(userId);
                if (context.mounted) Navigator.pop(context);
              } on DomainException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
          ),
        ],
      ),
      body: usersAsync.when(
        data: (users) {
          final matches = users.where((u) => u.id == userId).toList();
          if (matches.isEmpty) return const Center(child: Text('Пользователь не найден'));
          final user = matches.first;
          return ListView(
            children: [
              ListTile(title: const Text('Имя'), subtitle: Text(user.name)),
              ListTile(title: const Text('Email'), subtitle: Text(user.email)),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Назначенные задачи', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              tasksAsync.when(
                data: (tasks) => tasks.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Нет задач'),
                      )
                    : Column(children: tasks.map((t) => TaskTile(task: t)).toList()),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Ошибка: $e'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
      ),
    );
  }
}