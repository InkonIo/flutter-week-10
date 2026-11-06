// dart | lib/repository/task_repository.dart | flutter/drift | task CRUD, history, soft delete, undo
import 'package:drift/drift.dart';
import '../database/database.dart';
import 'exceptions.dart';

enum TaskSortField { createdAt, deadline }

class TaskFilter {
  final int? projectId;
  final int? assigneeId;
  final TaskStatus? status;
  final TaskPriority? priority;
  final String? search;
  final TaskSortField sortField;
  final bool ascending;
  final int page;
  final int pageSize;

  const TaskFilter({
    this.projectId,
    this.assigneeId,
    this.status,
    this.priority,
    this.search,
    this.sortField = TaskSortField.createdAt,
    this.ascending = false,
    this.page = 0,
    this.pageSize = 25,
  });
}

class TaskRepository {
  final AppDatabase db;
  const TaskRepository(this.db);

  Future<User> _requireCurrentActor(int actingUserId) async {
    final u = await (db.select(db.users)..where((x) => x.id.equals(actingUserId)))
        .getSingleOrNull();
    if (u == null) {
      throw const DomainException('Пользователь, выполняющий действие, не найден');
    }
    return u;
  }

  Future<void> _assertProjectMember(int projectId, int userId) async {
    final member = await (db.select(db.projectMembers)
          ..where((m) => m.projectId.equals(projectId) & m.userId.equals(userId)))
        .getSingleOrNull();
    if (member == null) throw const NotProjectMemberException();
  }

  Future<void> _assertAssigneeDeadlineCapacity({
    required int assigneeId,
    required DateTime deadline,
    int? excludingTaskId,
  }) async {
    final dayStart = DateTime(deadline.year, deadline.month, deadline.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final query = db.select(db.tasks)
      ..where((t) =>
          t.assigneeId.equals(assigneeId) &
          t.deletedAt.isNull() &
          (t.status.equalsValue(TaskStatus.todo) |
              t.status.equalsValue(TaskStatus.inProgress)) &
          t.deadline.isBiggerOrEqualValue(dayStart) &
          t.deadline.isSmallerThanValue(dayEnd));
    if (excludingTaskId != null) {
      query.where((t) => t.id.equals(excludingTaskId).not());
    }
    final count = (await query.get()).length;
    if (count >= 3) throw const TaskLimitExceededException();
  }

  Stream<List<Task>> watchFiltered(TaskFilter filter) {
    final query = _buildFilteredQuery(filter);
    return query.watch();
  }

  Future<List<Task>> getFiltered(TaskFilter filter) {
    final query = _buildFilteredQuery(filter);
    return query.get();
  }

  SimpleSelectStatement<$TasksTable, Task> _buildFilteredQuery(TaskFilter filter) {
    final query = db.select(db.tasks)..where((t) => t.deletedAt.isNull());
    if (filter.projectId != null) {
      query.where((t) => t.projectId.equals(filter.projectId!));
    }
    if (filter.assigneeId != null) {
      query.where((t) => t.assigneeId.equals(filter.assigneeId!));
    }
    if (filter.status != null) {
      query.where((t) => t.status.equalsValue(filter.status!));
    }
    if (filter.priority != null) {
      query.where((t) => t.priority.equalsValue(filter.priority!));
    }
    if (filter.search != null && filter.search!.trim().isNotEmpty) {
      final like = '%${filter.search!.trim()}%';
      query.where((t) => t.title.like(like) | t.description.like(like));
    }
    final column = filter.sortField == TaskSortField.createdAt
        ? (db.tasks.createdAt)
        : (db.tasks.deadline);
    query.orderBy([
      (t) => filter.ascending
          ? OrderingTerm.asc(column)
          : OrderingTerm.desc(column)
    ]);
    query.limit(filter.pageSize, offset: filter.page * filter.pageSize);
    return query;
  }

  Future<Task?> getById(int id) =>
      (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<TaskHistoryEntry>> watchHistory(int taskId) {
    final q = db.select(db.taskHistory)
      ..where((h) => h.taskId.equals(taskId))
      ..orderBy([(h) => OrderingTerm.desc(h.changedAt)]);
    return q.watch();
  }

  /// creates a task and its first history row ('null' -> initial status) as
  /// one atomic transaction (requirement 4.1): if the history insert fails,
  /// the task insert is rolled back too.
  Future<Task> create({
    required String title,
    String description = '',
    required int projectId,
    int? assigneeId,
    TaskPriority priority = TaskPriority.medium,
    TaskStatus status = TaskStatus.todo,
    DateTime? deadline,
    required int actingUserId,
  }) async {
    await _requireCurrentActor(actingUserId);

    final project = await (db.select(db.projects)
          ..where((p) => p.id.equals(projectId)))
        .getSingleOrNull();
    if (project == null) {
      throw const DomainException('Нельзя создать задачу без проекта');
    }

    if (assigneeId != null) {
      await _assertProjectMember(projectId, assigneeId);
      if (deadline != null) {
        await _assertAssigneeDeadlineCapacity(
            assigneeId: assigneeId, deadline: deadline);
      }
    }

    return db.transaction(() async {
      final now = DateTime.now();
      final id = await db.into(db.tasks).insert(
            TasksCompanion.insert(
              title: title,
              description: Value(description),
              projectId: projectId,
              assigneeId: Value(assigneeId),
              priority: Value(priority),
              status: Value(status),
              deadline: Value(deadline),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db.into(db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: id,
              previousStatus: const Value(null),
              newStatus: status.name,
              changedBy: actingUserId,
            ),
          );
      return (await getById(id))!;
    });
  }

  Future<void> update(Task task) async {
    await db.update(db.tasks).replace(
          task.copyWith(updatedAt: DateTime.now()),
        );
  }

  Future<void> changeStatus({
    required int taskId,
    required TaskStatus newStatus,
    required int actingUserId,
  }) async {
    await _requireCurrentActor(actingUserId);
    await db.transaction(() async {
      final task = await getById(taskId);
      if (task == null) throw const TaskNotFoundException();
      await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          status: Value(newStatus),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await db.into(db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              previousStatus: Value(task.status.name),
              newStatus: newStatus.name,
              changedBy: actingUserId,
            ),
          );
    });
  }

  Future<void> changePriority(int taskId, TaskPriority priority) async {
    await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(priority: Value(priority), updatedAt: Value(DateTime.now())),
    );
  }

  /// reassigns the task's executor. Checks project membership, updates the
  /// task and writes a history row, all inside one transaction (4.1).
  Future<void> reassign({
    required int taskId,
    required int newAssigneeId,
    required int actingUserId,
  }) async {
    await _requireCurrentActor(actingUserId);
    await db.transaction(() async {
      final task = await getById(taskId);
      if (task == null) throw const TaskNotFoundException();
      await _assertProjectMember(task.projectId, newAssigneeId);
      if (task.deadline != null) {
        await _assertAssigneeDeadlineCapacity(
          assigneeId: newAssigneeId,
          deadline: task.deadline!,
          excludingTaskId: taskId,
        );
      }
      await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          assigneeId: Value(newAssigneeId),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await db.into(db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              previousStatus: Value('assignee:${task.assigneeId}'),
              newStatus: 'assignee:$newAssigneeId',
              changedBy: actingUserId,
            ),
          );
    });
  }

  /// undoes the most recent status change recorded in history (requirement
  /// 5, task 2). Writes a new history row for the revert itself, it does
  /// not delete the undone entry, so the audit trail stays intact.
  Future<void> undoLastStatusChange({
    required int taskId,
    required int actingUserId,
  }) async {
    await db.transaction(() async {
      final recentEntries = await (db.select(db.taskHistory)
            ..where((h) => h.taskId.equals(taskId))
            ..orderBy([(h) => OrderingTerm.desc(h.changedAt)])
            ..limit(50))
          .get();
      final statusEntries =
          recentEntries.where((h) => !h.newStatus.startsWith('assignee:'));
      final last = statusEntries.isEmpty ? null : statusEntries.first;
      if (last == null || last.previousStatus == null) {
        throw const NoHistoryToUndoException();
      }
      final revertTo = TaskStatus.values.byName(last.previousStatus!);
      final task = await getById(taskId);
      if (task == null) throw const TaskNotFoundException();
      await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(status: Value(revertTo), updatedAt: Value(DateTime.now())),
      );
      await db.into(db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              previousStatus: Value(task.status.name),
              newStatus: revertTo.name,
              changedBy: actingUserId,
            ),
          );
    });
  }

  // ---------------- soft delete (requirement 5, task 1) ----------------

  Future<void> softDelete(int taskId) async {
    await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  Future<void> restore(int taskId) async {
    await (db.update(db.tasks)..where((t) => t.id.equals(taskId))).write(
      const TasksCompanion(deletedAt: Value(null)),
    );
  }

  Future<void> purge(int taskId) =>
      (db.delete(db.tasks)..where((t) => t.id.equals(taskId))).go();

  Stream<List<Task>> watchDeleted() {
    final q = db.select(db.tasks)
      ..where((t) => t.deletedAt.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]);
    return q.watch();
  }
}
