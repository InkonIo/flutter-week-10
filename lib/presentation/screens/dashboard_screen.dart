// dart | lib/presentation/screens/dashboard_screen.dart | flutter | stats computed via SQL (DashboardRepository)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final usersAsync = ref.watch(allUsersProvider);

    return statsAsync.when(
      data: (stats) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(label: 'Проекты', value: '${stats.totalProjects}'),
              _StatCard(label: 'Всего задач', value: '${stats.totalTasks}'),
              _StatCard(label: 'Завершено', value: '${stats.completedTasks}'),
              _StatCard(label: 'Не завершено', value: '${stats.incompleteTasks}'),
              _StatCard(label: 'Просрочено', value: '${stats.overdueTasks}', color: Colors.red),
            ],
          ),
          const SizedBox(height: 24),
          const Text('По приоритету', style: TextStyle(fontWeight: FontWeight.bold)),
          ...stats.tasksByPriority.entries.map(
            (e) => ListTile(dense: true, title: Text(e.key.name), trailing: Text('${e.value}')),
          ),
          const SizedBox(height: 24),
          const Text('По исполнителю', style: TextStyle(fontWeight: FontWeight.bold)),
          usersAsync.when(
            data: (users) => Column(
              children: stats.tasksByAssignee.entries.map((e) {
                final match = users.where((u) => u.id == e.key).toList();
                final name = match.isEmpty ? '#${e.key}' : match.first.name;
                return ListTile(dense: true, title: Text(name), trailing: Text('${e.value}'));
              }).toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Ошибка: $e'),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatCard({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: color)),
            Text(label),
          ],
        ),
      ),
    );
  }
}