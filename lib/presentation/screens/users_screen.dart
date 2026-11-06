// dart | lib/presentation/screens/users_screen.dart | flutter | user list + create + delete
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// ignore: unused_import
import '../../database/database.dart';
import '../../providers/providers.dart';
import '../../repository/exceptions.dart';
import 'user_detail_screen.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый пользователь'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Имя')),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(userRepositoryProvider).create(
            name: nameCtrl.text.trim(),
            email: emailCtrl.text.trim(),
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
    final fmt = DateFormat('dd.MM.yyyy');

    return Scaffold(
      body: usersAsync.when(
        data: (users) => users.isEmpty
            ? const Center(child: Text('Пока нет пользователей'))
            : ListView.builder(
                itemCount: users.length,
                itemBuilder: (ctx, i) {
                  final u = users[i];
                  return ListTile(
                    leading: CircleAvatar(child: Text(u.name.isNotEmpty ? u.name[0] : '?')),
                    title: Text(u.name),
                    subtitle: Text('${u.email} · с ${fmt.format(u.registeredAt)}'),
                    onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(builder: (_) => UserDetailScreen(userId: u.id)),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
