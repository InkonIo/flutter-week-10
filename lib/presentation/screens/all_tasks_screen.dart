// dart | lib/presentation/screens/all_tasks_screen.dart | flutter | search/filter/sort across all tasks (req. 2.3, 4.4)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/providers.dart';
import '../../repository/task_repository.dart';
import '../widgets/task_tile.dart';

class AllTasksScreen extends ConsumerStatefulWidget {
  const AllTasksScreen({super.key});

  @override
  ConsumerState<AllTasksScreen> createState() => _AllTasksScreenState();
}

class _AllTasksScreenState extends ConsumerState<AllTasksScreen> {
  int? _projectId;
  TaskStatus? _status;
  TaskPriority? _priority;
  int? _assigneeId;
  String _search = '';
  TaskSortField _sortField = TaskSortField.createdAt;
  bool _ascending = false;
  int _page = 0;
  static const _pageSize = 50;

  @override
  Widget build(BuildContext context) {
    final taskRepo = ref.watch(taskRepositoryProvider);
    final projectsAsync = ref.watch(allProjectsProvider);
    final usersAsync = ref.watch(allUsersProvider);

    final filter = TaskFilter(
      projectId: _projectId,
      status: _status,
      priority: _priority,
      assigneeId: _assigneeId,
      search: _search.trim().isEmpty ? null : _search.trim(),
      sortField: _sortField,
      ascending: _ascending,
      page: _page,
      pageSize: _pageSize,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Все задачи')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск по названию/описанию',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() {
                _search = v;
                _page = 0;
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                projectsAsync.when(
                  data: (projects) => DropdownButton<int?>(
                    value: _projectId,
                    hint: const Text('Проект'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Все проекты')),
                      ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                    ],
                    onChanged: (v) => setState(() {
                      _projectId = v;
                      _page = 0;
                    }),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                DropdownButton<TaskStatus?>(
                  value: _status,
                  hint: const Text('Статус'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все статусы')),
                    ...TaskStatus.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(statusLabel(s)))),
                  ],
                  onChanged: (v) => setState(() {
                    _status = v;
                    _page = 0;
                  }),
                ),
                DropdownButton<TaskPriority?>(
                  value: _priority,
                  hint: const Text('Приоритет'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Все приоритеты')),
                    ...TaskPriority.values
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.name))),
                  ],
                  onChanged: (v) => setState(() {
                    _priority = v;
                    _page = 0;
                  }),
                ),
                usersAsync.when(
                  data: (users) => DropdownButton<int?>(
                    value: _assigneeId,
                    hint: const Text('Исполнитель'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Все исполнители')),
                      ...users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                    ],
                    onChanged: (v) => setState(() {
                      _assigneeId = v;
                      _page = 0;
                    }),
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
          const Divider(height: 24),
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: taskRepo.watchFiltered(filter),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final tasks = snap.data!;
                if (tasks.isEmpty && _page == 0) {
                  return const Center(child: Text('Ничего не найдено'));
                }
                return ListView(
                  children: [
                    ...tasks.map((t) => TaskTile(task: t)),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton(
                            onPressed: _page > 0 ? () => setState(() => _page--) : null,
                            child: const Text('Назад'),
                          ),
                          Text('Страница ${_page + 1}'),
                          OutlinedButton(
                            onPressed: tasks.length == _pageSize
                                ? () => setState(() => _page++)
                                : null,
                            child: const Text('Дальше'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}