// dart | lib/providers/providers.dart | flutter_riverpod | DB + repository + reactive state
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../repository/user_repository.dart';
import '../repository/project_repository.dart';
import '../repository/task_repository.dart';
import '../repository/comment_repository.dart';
import '../repository/attachment_repository.dart';
import '../repository/history_repository.dart';
import '../repository/dashboard_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final userRepositoryProvider =
    Provider((ref) => UserRepository(ref.watch(databaseProvider)));
final projectRepositoryProvider =
    Provider((ref) => ProjectRepository(ref.watch(databaseProvider)));
final taskRepositoryProvider =
    Provider((ref) => TaskRepository(ref.watch(databaseProvider)));
final commentRepositoryProvider =
    Provider((ref) => CommentRepository(ref.watch(databaseProvider)));
final attachmentRepositoryProvider =
    Provider((ref) => AttachmentRepository(ref.watch(databaseProvider)));
final historyRepositoryProvider =
    Provider((ref) => HistoryRepository(ref.watch(databaseProvider)));
final dashboardRepositoryProvider =
    Provider((ref) => DashboardRepository(ref.watch(databaseProvider)));

/// id of the user currently "logged in" on this device — drives who shows
/// up as the actor in history rows / comment authorship / undo checks.
final currentUserIdProvider = StateProvider<int?>((ref) => null);

final allUsersProvider = StreamProvider<List<User>>(
  (ref) => ref.watch(userRepositoryProvider).watchAll(),
);

final allProjectsProvider = StreamProvider<List<Project>>(
  (ref) => ref.watch(projectRepositoryProvider).watchAll(),
);

final projectMembersProvider =
    StreamProvider.family<List<ProjectMember>, int>(
  (ref, projectId) =>
      ref.watch(projectRepositoryProvider).watchMembers(projectId),
);

final tasksForProjectProvider = StreamProvider.family<List<Task>, int>(
  (ref, projectId) => ref.watch(projectRepositoryProvider).watchTasks(projectId),
);

final tasksForUserProvider = StreamProvider.family<List<Task>, int>(
  (ref, userId) => ref.watch(userRepositoryProvider).watchTasksForUser(userId),
);

final taskFilterProvider = StateProvider<TaskFilter>((ref) => const TaskFilter());

final filteredTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref
      .watch(taskRepositoryProvider)
      .watchFiltered(ref.watch(taskFilterProvider)),
);

final taskHistoryProvider = StreamProvider.family<List<TaskHistoryEntry>, int>(
  (ref, taskId) => ref.watch(historyRepositoryProvider).watchForTask(taskId),
);

final taskCommentsProvider = StreamProvider.family<List<Comment>, int>(
  (ref, taskId) => ref.watch(commentRepositoryProvider).watchForTask(taskId),
);

final taskAttachmentsProvider = StreamProvider.family<List<Attachment>, int>(
  (ref, taskId) => ref.watch(attachmentRepositoryProvider).watchForTask(taskId),
);

final deletedTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchDeleted(),
);

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>(
  (ref) => ref.watch(dashboardRepositoryProvider).load(),
);

final projectCompletionProvider = FutureProvider.family<double, int>(
  (ref, projectId) =>
      ref.watch(dashboardRepositoryProvider).projectCompletion(projectId),
);
