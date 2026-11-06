// dart | lib/repository/dashboard_repository.dart | flutter/drift | aggregated stats for the dashboard screen
import '../database/database.dart';

class DashboardStats {
  final int totalProjects;
  final int totalTasks;
  final int completedTasks;
  final int incompleteTasks;
  final int overdueTasks;
  final Map<TaskPriority, int> tasksByPriority;
  final Map<int, int> tasksByAssignee;

  const DashboardStats({
    required this.totalProjects,
    required this.totalTasks,
    required this.completedTasks,
    required this.incompleteTasks,
    required this.overdueTasks,
    required this.tasksByPriority,
    required this.tasksByAssignee,
  });
}

class DashboardRepository {
  final AppDatabase db;
  const DashboardRepository(this.db);

  Future<DashboardStats> load() async {
    final totalTasks = await db.countTasks();
    final completed = await db.countTasksByStatus(TaskStatus.done);
    return DashboardStats(
      totalProjects: await db.countProjects(),
      totalTasks: totalTasks,
      completedTasks: completed,
      incompleteTasks: totalTasks - completed,
      overdueTasks: await db.countOverdueTasks(),
      tasksByPriority: await db.countTasksByPriority(),
      tasksByAssignee: await db.countTasksByAssignee(),
    );
  }

  Future<double> projectCompletion(int projectId) =>
      db.projectCompletionPercent(projectId);
}
