// dart | lib/presentation/screens/home_screen.dart | flutter | bottom-nav shell
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import 'users_screen.dart';
import 'projects_screen.dart';
import 'all_tasks_screen.dart';
import 'dashboard_screen.dart';
import 'trash_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  static const _screens = [
    ProjectsScreen(),
    AllTasksScreen(),
    UsersScreen(),
    DashboardScreen(),
    TrashScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserIdProvider);
    final users = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskFlow'),
        actions: [
          users.when(
            data: (list) => DropdownButton<int>(
              value: currentUser,
              hint: const Text('Активный пользователь', style: TextStyle(fontSize: 12)),
              underline: const SizedBox.shrink(),
              items: list
                  .map((u) => DropdownMenuItem(value: u.id, child: Text(u.name)))
                  .toList(),
              onChanged: (v) =>
                  ref.read(currentUserIdProvider.notifier).state = v,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder), label: 'Проекты'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Задачи'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Пользователи'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Статистика'),
          NavigationDestination(icon: Icon(Icons.delete), label: 'Корзина'),
        ],
      ),
    );
  }
}