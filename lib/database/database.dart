// dart | lib/database/database.dart | flutter/drift | TaskFlow local SQLite schema + migrations
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

// ---------------- enums ----------------

enum ProjectStatus { active, completed, archived }

enum ProjectRole { owner, admin, member }

enum TaskStatus { todo, inProgress, done, cancelled }

enum TaskPriority { low, medium, high, critical }

class ProjectStatusConverter extends TypeConverter<ProjectStatus, String> {
  const ProjectStatusConverter();
  @override
  ProjectStatus fromSql(String fromDb) => ProjectStatus.values.byName(fromDb);
  @override
  String toSql(ProjectStatus value) => value.name;
}

class ProjectRoleConverter extends TypeConverter<ProjectRole, String> {
  const ProjectRoleConverter();
  @override
  ProjectRole fromSql(String fromDb) => ProjectRole.values.byName(fromDb);
  @override
  String toSql(ProjectRole value) => value.name;
}

class TaskStatusConverter extends TypeConverter<TaskStatus, String> {
  const TaskStatusConverter();
  @override
  TaskStatus fromSql(String fromDb) => TaskStatus.values.byName(fromDb);
  @override
  String toSql(TaskStatus value) => value.name;
}

class TaskPriorityConverter extends TypeConverter<TaskPriority, String> {
  const TaskPriorityConverter();
  @override
  TaskPriority fromSql(String fromDb) => TaskPriority.values.byName(fromDb);
  @override
  String toSql(TaskPriority value) => value.name;
}

// ---------------- tables ----------------

@DataClassName('User')
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get email => text().withLength(min: 3, max: 255)();
  DateTimeColumn get registeredAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {email}
      ];
}

@TableIndex(name: 'idx_projects_status', columns: {#status})
@DataClassName('Project')
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get status => text()
      .map(const ProjectStatusConverter())
      .withDefault(const Constant('active'))();
}

@TableIndex(name: 'idx_members_project', columns: {#projectId})
@TableIndex(name: 'idx_members_user', columns: {#userId})
@DataClassName('ProjectMember')
class ProjectMembers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get userId =>
      integer().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()
      .map(const ProjectRoleConverter())
      .withDefault(const Constant('member'))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {projectId, userId}
      ];
}

@TableIndex(name: 'idx_tasks_project', columns: {#projectId})
@TableIndex(name: 'idx_tasks_assignee', columns: {#assigneeId})
@TableIndex(name: 'idx_tasks_status', columns: {#status})
@TableIndex(name: 'idx_tasks_deadline', columns: {#deadline})
@TableIndex(name: 'idx_tasks_deleted', columns: {#deletedAt})
@DataClassName('Task')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get assigneeId =>
      integer().nullable().references(Users, #id, onDelete: KeyAction.setNull)();
  TextColumn get priority => text()
      .map(const TaskPriorityConverter())
      .withDefault(const Constant('medium'))();
  TextColumn get status => text()
      .map(const TaskStatusConverter())
      .withDefault(const Constant('todo'))();
  DateTimeColumn get deadline => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@TableIndex(name: 'idx_history_task', columns: {#taskId})
@DataClassName('TaskHistoryEntry')
class TaskHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get previousStatus => text().nullable()();
  TextColumn get newStatus => text()();
  IntColumn get changedBy =>
      integer().references(Users, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get changedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'idx_comments_task', columns: {#taskId})
@DataClassName('Comment')
class Comments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get authorId =>
      integer().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text().withLength(min: 1, max: 4000)();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

@TableIndex(name: 'idx_attachments_task', columns: {#taskId})
@DataClassName('Attachment')
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get fileName => text().withLength(min: 1, max: 255)();
  TextColumn get filePath => text()();
  DateTimeColumn get addedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ---------------- database ----------------

@DriftDatabase(tables: [
  Users,
  Projects,
  ProjectMembers,
  Tasks,
  TaskHistory,
  Comments,
  Attachments,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  // schemaVersion = 2: v1 shipped without tasks.priority; v2 adds it (see migration below).
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from == 1) {
            // v1 -> v2: tasks had no priority column. Add it and backfill
            // every existing row with the default 'medium' so no data is lost.
            await m.addColumn(tasks, tasks.priority);
            await customStatement(
              "UPDATE tasks SET priority = 'medium' WHERE priority IS NULL",
            );
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'taskflow.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  // ---------------- dashboard / raw SQL stats (requirement 2.7) ----------------

  Future<int> countProjects() async {
    final row = await customSelect('SELECT COUNT(*) AS c FROM projects')
        .getSingle();
    return row.read<int>('c');
  }

  Future<int> countTasks({bool includeDeleted = false}) async {
    final where = includeDeleted ? '' : 'WHERE deleted_at IS NULL';
    final row =
        await customSelect('SELECT COUNT(*) AS c FROM tasks $where')
            .getSingle();
    return row.read<int>('c');
  }

  Future<int> countTasksByStatus(TaskStatus status) async {
    final row = await customSelect(
      'SELECT COUNT(*) AS c FROM tasks WHERE deleted_at IS NULL AND status = ?',
      variables: [Variable.withString(status.name)],
    ).getSingle();
    return row.read<int>('c');
  }

  Future<int> countOverdueTasks() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final row = await customSelect(
      '''
      SELECT COUNT(*) AS c FROM tasks
      WHERE deleted_at IS NULL
        AND status NOT IN ('done', 'cancelled')
        AND deadline IS NOT NULL
        AND deadline < ?
      ''',
      variables: [Variable.withInt(nowMs)],
    ).getSingle();
    return row.read<int>('c');
  }

  Future<Map<TaskPriority, int>> countTasksByPriority() async {
    final rows = await customSelect(
      '''
      SELECT priority, COUNT(*) AS c FROM tasks
      WHERE deleted_at IS NULL
      GROUP BY priority
      ''',
    ).get();
    final result = <TaskPriority, int>{
      for (final p in TaskPriority.values) p: 0,
    };
    for (final row in rows) {
      final priority = TaskPriority.values.byName(row.read<String>('priority'));
      result[priority] = row.read<int>('c');
    }
    return result;
  }

  Future<Map<int, int>> countTasksByAssignee() async {
    final rows = await customSelect(
      '''
      SELECT assignee_id, COUNT(*) AS c FROM tasks
      WHERE deleted_at IS NULL AND assignee_id IS NOT NULL
      GROUP BY assignee_id
      ''',
    ).get();
    return {
      for (final row in rows)
        row.read<int>('assignee_id'): row.read<int>('c'),
    };
  }

  /// percent of a project's tasks that are 'done' (0-100, 0 if no tasks).
  Future<double> projectCompletionPercent(int projectId) async {
    final row = await customSelect(
      '''
      SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) AS done_count
      FROM tasks
      WHERE deleted_at IS NULL AND project_id = ?
      ''',
      variables: [Variable.withInt(projectId)],
    ).getSingle();
    final total = row.read<int>('total');
    if (total == 0) return 0;
    final done = row.read<int?>('done_count') ?? 0;
    return done * 100.0 / total;
  }
}