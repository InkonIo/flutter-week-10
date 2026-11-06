// dart | lib/presentation/screens/task_form_screen.dart | flutter | create task form
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/providers.dart';
import '../../repository/exceptions.dart';

class TaskFormScreen extends ConsumerStatefulWidget {
  final int projectId;
  const TaskFormScreen({super.key, required this.projectId});

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  int? _assigneeId;
  DateTime? _deadline;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(projectMembersProvider(widget.projectId));
    final usersAsync = ref.watch(allUsersProvider);
    final actingUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Новая задача')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Название')),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Описание'), maxLines: 3),
            const SizedBox(height: 12),
            DropdownButtonFormField<TaskPriority>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Приоритет'),
              items: TaskPriority.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v!),
            ),
            const SizedBox(height: 12),
            membersAsync.when(
              data: (members) => usersAsync.when(
                data: (users) {
                  final memberUsers = users
                      .where((u) => members.any((m) => m.userId == u.id))
                      .toList();
                  return DropdownButtonFormField<int>(
                    value: _assigneeId,
                    decoration: const InputDecoration(labelText: 'Исполнитель (участник проекта)'),
                    items: memberUsers
                        .map((u) => DropdownMenuItem(value: u.id, child: Text(u.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _assigneeId = v),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Ошибка загрузки пользователей'),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Ошибка загрузки участников'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_deadline == null
                  ? 'Дедлайн не выбран'
                  : 'Дедлайн: ${_deadline!.toLocal().toString().split(' ').first}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (d != null) setState(() => _deadline = d);
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      if (_titleCtrl.text.trim().isEmpty) return;
                      if (actingUserId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Выберите активного пользователя вверху экрана')),
                        );
                        return;
                      }
                      setState(() => _saving = true);
                      try {
                        await ref.read(taskRepositoryProvider).create(
                              title: _titleCtrl.text.trim(),
                              description: _descCtrl.text.trim(),
                              projectId: widget.projectId,
                              assigneeId: _assigneeId,
                              priority: _priority,
                              deadline: _deadline,
                              actingUserId: actingUserId,
                            );
                        if (context.mounted) Navigator.pop(context);
                      } on DomainException catch (e) {
                        setState(() => _saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(e.message)));
                        }
                      }
                    },
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }
}
