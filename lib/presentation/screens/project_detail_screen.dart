// dart | lib/presentation/screens/project_detail_screen.dart | flutter | members+roles, filtered/sorted/searched tasks
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/providers.dart';
import '../../repository/exceptions.dart';
import '../../repository/task_repository.dart';
import '../widgets/task_tile.dart';
import 'task_form_screen.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  TaskStatus? _status;
  TaskPriority? _priority;
  int? _assigneeId;
  String _search = '';
  TaskSortField _sortField = TaskSortField.createdAt;
  bool _ascending = false;

  Future<void> _addMember(BuildContext context, WidgetRef ref) async {
    final users = await ref.read(allUsersProvider.future);
    if (!context.mounted) return;
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Добавить участника'),
        children: users
            .map((u) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, u.id),
                  child: Text('${u.name} (${u.email})'),
                ))
            .toList(),
      ),
    );
    if (selected == null) return;
    try {
      await ref
          .read(projectRepositoryProvider)
          .addMember(projectId: widget.projectId, userId: selected);
    } on DomainException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(projectMembersProvider(widget.projectId));
    final usersAsync = ref.watch(allUsersProvider);
    final completionAsync = ref.watch(projectCompletionProvider(widget.projectId));
    final taskRepo = ref.watch(taskRepositoryProvider);

    final filter = TaskFilter(
      projectId: widget.projectId,
      status: _status,
      priority: _priority,
      assigneeId: _assigneeId,
      search: _search.trim().isEmpty ? null : _search.trim(),
      sortField: _sortField,
      ascending: _ascending,
      pageSize: 200,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Проект')),
      body: ListView(
        children: [
          completionAsync.when(
            data: (pct) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Выполнено: ${pct.toStringAsFixed(0)}%'),
                  LinearProgressIndicator(value: pct / 100),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Участники', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => _addMember(context, ref),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Добавить'),
                ),
              ],
            ),
          ),
          membersAsync.when(
            data: (members) => usersAsync.when(
              data: (users) => Column(
                children: members.map((m) {
                  final u = users.where((x) => x.id == m.userId).toList();
                  final name = u.isEmpty ? '#${m.userId}' : u.first.name;
                  return ListTile(
                    title: Text(name),
                    subtitle: DropdownButton<ProjectRole>(
                      value: m.role,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      items: ProjectRole.values
                          .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                          .toList(),
                      onChanged: (r) {
                        if (r == null) return;
                        ref.read(projectRepositoryProvider).setRole(
                              projectId: widget.projectId,
                              userId: m.userId,
                              role: r,
                            );
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => ref
                          .read(projectRepositoryProvider)
                          .removeMember(widget.projectId, m.userId),
                    ),
                  );
                }).toList(),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Ошибка: $e'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Задачи', style: Theme.of(context).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск по названию/описанию',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownButton<TaskStatus?>(
                  value: _status,
                  hint: const Text('Статус'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все статусы')),
                    ...TaskStatus.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(statusLabel(s)))),
                  ],
                  onChanged: (v) => setState(() => _status = v),
                ),
                DropdownButton<TaskPriority?>(
                  value: _priority,
                  hint: const Text('Приоритет'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все приоритеты')),
                    ...TaskPriority.values
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.name))),
                  ],
                  onChanged: (v) => setState(() => _priority = v),
                ),
                membersAsync.when(
                  data: (members) => usersAsync.when(
                    data: (users) => DropdownButton<int?>(
                      value: _assigneeId,
                      hint: const Text('Исполнитель'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Все исполнители')),
                        ...members.map((m) {
                          final u = users.where((x) => x.id == m.userId).toList();
                          final name = u.isEmpty ? '#${m.userId}' : u.first.name;
                          return DropdownMenuItem(value: m.userId, child: Text(name));
                        }),
                      ],
                      onChanged: (v) => setState(() => _assigneeId = v),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                DropdownButton<TaskSortField>(
                  value: _sortField,
                  items: const [
                    DropdownMenuItem(value: TaskSortField.createdAt, child: Text('Сорт.: дата создания')),
                    DropdownMenuItem(value: TaskSortField.deadline, child: Text('Сорт.: дедлайн')),
                  ],
                  onChanged: (v) => setState(() => _sortField = v ?? TaskSortField.createdAt),
                ),
                IconButton(
                  tooltip: _ascending ? 'По возрастанию' : 'По убыванию',
                  icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
                  onPressed: () => setState(() => _ascending = !_ascending),
                ),
              ],
            ),
          ),
          StreamBuilder<List<Task>>(
            stream: taskRepo.watchFiltered(filter),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final tasks = snap.data!;
              if (tasks.isEmpty) {
                return const Padding(padding: EdgeInsets.all(16), child: Text('Нет задач'));
              }
              return Column(children: tasks.map((t) => TaskTile(task: t)).toList());
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskFormScreen(projectId: widget.projectId)),
        ),
        icon: const Icon(Icons.add_task),
        label: const Text('Задача'),
      ),
    );
  }
}