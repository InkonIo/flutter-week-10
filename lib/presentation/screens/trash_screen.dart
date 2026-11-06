// dart | lib/presentation/screens/trash_screen.dart | flutter | soft-deleted tasks: restore / purge
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedAsync = ref.watch(deletedTasksProvider);
    final taskRepo = ref.watch(taskRepositoryProvider);

    return deletedAsync.when(
      data: (tasks) => tasks.isEmpty
          ? const Center(child: Text('Корзина пуста'))
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (ctx, i) {
                final t = tasks[i];
                return ListTile(
                  title: Text(t.title),
                  subtitle: Text('удалено: ${t.deletedAt!.toLocal()}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore),
                        tooltip: 'Восстановить',
                        onPressed: () => taskRepo.restore(t.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        tooltip: 'Удалить навсегда',
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: ctx,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('Удалить навсегда?'),
                              content: Text('«${t.title}» будет удалена без возможности восстановления.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(dCtx, false),
                                    child: const Text('Отмена')),
                                FilledButton(
                                    onPressed: () => Navigator.pop(dCtx, true),
                                    child: const Text('Удалить')),
                              ],
                            ),
                          );
                          if (ok == true) await taskRepo.purge(t.id);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
    );
  }
}
