// dart | lib/presentation/screens/projects_screen.dart | flutter | project list + create
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/providers.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый проект'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Описание')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(projectRepositoryProvider).create(
          name: nameCtrl.text.trim(),
          description: descCtrl.text.trim(),
        );
  }

  Color _statusColor(ProjectStatus s) {
    switch (s) {
      case ProjectStatus.active:
        return Colors.green;
      case ProjectStatus.completed:
        return Colors.blue;
      case ProjectStatus.archived:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(allProjectsProvider);

    return Scaffold(
      body: projectsAsync.when(
        data: (projects) => projects.isEmpty
            ? const Center(child: Text('Пока нет проектов'))
            : ListView.builder(
                itemCount: projects.length,
                itemBuilder: (ctx, i) {
                  final p = projects[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _statusColor(p.status),
                        child: const Icon(Icons.folder, color: Colors.white, size: 18),
                      ),
                      title: Text(p.name),
                      subtitle: Text(p.description.isEmpty ? p.status.name : p.description),
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: p.id)),
                      ),
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
