// dart | lib/presentation/screens/task_detail_screen.dart | flutter | status/priority/assignee/comments/attachments/history
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/providers.dart';
import '../../repository/exceptions.dart';
import '../widgets/task_tile.dart';

class TaskDetailScreen extends ConsumerWidget {
  final int taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  Future<void> _requireActor(BuildContext context, WidgetRef ref, Future<void> Function(int actingUserId) action) async {
    final actingUserId = ref.read(currentUserIdProvider);
    if (actingUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите активного пользователя вверху экрана')),
      );
      return;
    }
    try {
      await action(actingUserId);
    } on DomainException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _editTitleDescription(BuildContext context, WidgetRef ref, Task task) async {
    final titleCtrl = TextEditingController(text: task.title);
    final descCtrl = TextEditingController(text: task.description);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать задачу'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Название')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Описание'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(taskRepositoryProvider).update(
          task.copyWith(title: titleCtrl.text.trim(), description: descCtrl.text.trim()),
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskRepo = ref.watch(taskRepositoryProvider);
    final historyAsync = ref.watch(taskHistoryProvider(taskId));
    final commentsAsync = ref.watch(taskCommentsProvider(taskId));
    final attachmentsAsync = ref.watch(taskAttachmentsProvider(taskId));
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Задача'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Отменить последнее изменение статуса',
            onPressed: () => _requireActor(context, ref, (actingUserId) =>
                taskRepo.undoLastStatusChange(taskId: taskId, actingUserId: actingUserId)),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'В корзину',
            onPressed: () async {
              await taskRepo.softDelete(taskId);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: FutureBuilder<Task?>(
        future: taskRepo.getById(taskId),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final task = snap.data;
          if (task == null) return const Center(child: Text('Задача не найдена'));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(task.title, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Изменить название/описание',
                    onPressed: () => _editTitleDescription(context, ref, task),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(task.description),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TaskStatus>(
                      value: task.status,
                      decoration: const InputDecoration(labelText: 'Статус'),
                      items: TaskStatus.values
                          .map((s) => DropdownMenuItem(value: s, child: Text(statusLabel(s))))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        _requireActor(context, ref, (actingUserId) => taskRepo.changeStatus(
                              taskId: taskId,
                              newStatus: v,
                              actingUserId: actingUserId,
                            ));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<TaskPriority>(
                      value: task.priority,
                      decoration: const InputDecoration(labelText: 'Приоритет'),
                      items: TaskPriority.values
                          .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        taskRepo.changePriority(taskId, v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              usersAsync.when(
                data: (users) => DropdownButtonFormField<int>(
                  value: task.assigneeId,
                  decoration: const InputDecoration(labelText: 'Исполнитель'),
                  items: users
                      .map((u) => DropdownMenuItem(value: u.id, child: Text(u.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    _requireActor(context, ref, (actingUserId) => taskRepo.reassign(
                          taskId: taskId,
                          newAssigneeId: v,
                          actingUserId: actingUserId,
                        ));
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Ошибка загрузки пользователей'),
              ),
              const Divider(height: 32),
              const Text('История изменений', style: TextStyle(fontWeight: FontWeight.bold)),
              historyAsync.when(
                data: (history) => Column(
                  children: history
                      .map((h) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.history, size: 18),
                            title: Text('${h.previousStatus ?? '—'} → ${h.newStatus}'),
                            subtitle: Text(h.changedAt.toLocal().toString()),
                          ))
                      .toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Ошибка: $e'),
              ),
              const Divider(height: 32),
              const Text('Комментарии', style: TextStyle(fontWeight: FontWeight.bold)),
              commentsAsync.when(
                data: (comments) => Column(
                  children: comments
                      .map((c) => ListTile(
                            dense: true,
                            title: Text(c.content),
                            subtitle: Text(c.createdAt.toLocal().toString()),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => _requireActor(context, ref, (actingUserId) =>
                                  ref.read(commentRepositoryProvider).delete(
                                      commentId: c.id, requestingUserId: actingUserId)),
                            ),
                          ))
                      .toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Ошибка: $e'),
              ),
              _AddCommentField(taskId: taskId),
              const Divider(height: 32),
              const Text('Вложения', style: TextStyle(fontWeight: FontWeight.bold)),
              attachmentsAsync.when(
                data: (atts) => Column(
                  children: atts
                      .map((a) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.attach_file, size: 18),
                            title: Text(a.fileName),
                            subtitle: Text(a.filePath),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () =>
                                  ref.read(attachmentRepositoryProvider).delete(a.id),
                            ),
                          ))
                      .toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Ошибка: $e'),
              ),
              _AddAttachmentField(taskId: taskId),
            ],
          );
        },
      ),
    );
  }
}

class _AddCommentField extends ConsumerStatefulWidget {
  final int taskId;
  const _AddCommentField({required this.taskId});
  @override
  ConsumerState<_AddCommentField> createState() => _AddCommentFieldState();
}

class _AddCommentFieldState extends ConsumerState<_AddCommentField> {
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(hintText: 'Новый комментарий'),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send),
          onPressed: () async {
            final actingUserId = ref.read(currentUserIdProvider);
            if (actingUserId == null || _ctrl.text.trim().isEmpty) return;
            await ref.read(commentRepositoryProvider).add(
                  taskId: widget.taskId,
                  authorId: actingUserId,
                  text: _ctrl.text.trim(),
                );
            _ctrl.clear();
          },
        ),
      ],
    );
  }
}

class _AddAttachmentField extends ConsumerStatefulWidget {
  final int taskId;
  const _AddAttachmentField({required this.taskId});
  @override
  ConsumerState<_AddAttachmentField> createState() => _AddAttachmentFieldState();
}

class _AddAttachmentFieldState extends ConsumerState<_AddAttachmentField> {
  final _pathCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _pathCtrl,
            decoration: const InputDecoration(hintText: 'Локальный путь к файлу'),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.attach_file),
          onPressed: () async {
            final path = _pathCtrl.text.trim();
            if (path.isEmpty) return;
            final fileName = path.split(RegExp(r'[\\/]')).last;
            await ref.read(attachmentRepositoryProvider).add(
                  taskId: widget.taskId,
                  fileName: fileName,
                  filePath: path,
                );
            _pathCtrl.clear();
          },
        ),
      ],
    );
  }
}