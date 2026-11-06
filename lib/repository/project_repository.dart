// dart | lib/repository/project_repository.dart | flutter/drift | project + membership CRUD
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../database/database.dart';
import 'exceptions.dart';

class ProjectRepository {
  final AppDatabase db;
  const ProjectRepository(this.db);

  Stream<List<Project>> watchAll() => db.select(db.projects).watch();

  Future<Project?> getById(int id) => (db.select(db.projects)
        ..where((p) => p.id.equals(id)))
      .getSingleOrNull();

  Future<Project> create({
    required String name,
    String description = '',
    DateTime? completedAt,
    ProjectStatus status = ProjectStatus.active,
  }) async {
    final id = await db.into(db.projects).insert(
          ProjectsCompanion.insert(
            name: name,
            description: Value(description),
            completedAt: Value(completedAt),
            status: Value(status),
          ),
        );
    return (await getById(id))!;
  }

  Future<void> update(Project project) => db.update(db.projects).replace(project);

  Future<void> delete(int projectId) =>
      (db.delete(db.projects)..where((p) => p.id.equals(projectId))).go();

  // ---------------- members ----------------

  Stream<List<ProjectMember>> watchMembers(int projectId) =>
      (db.select(db.projectMembers)
            ..where((m) => m.projectId.equals(projectId)))
          .watch();

  Future<bool> isMember(int projectId, int userId) async {
    final row = await (db.select(db.projectMembers)
          ..where((m) => m.projectId.equals(projectId) & m.userId.equals(userId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> addMember({
    required int projectId,
    required int userId,
    ProjectRole role = ProjectRole.member,
  }) async {
    if (await isMember(projectId, userId)) {
      throw const DuplicateMemberException();
    }
    try {
      await db.into(db.projectMembers).insert(
            ProjectMembersCompanion.insert(
              projectId: projectId,
              userId: userId,
              role: Value(role),
            ),
          );
    } on SqliteException catch (e) {
      if (e.extendedResultCode == 2067 || e.message.contains('UNIQUE')) {
        throw const DuplicateMemberException();
      }
      rethrow;
    }
  }

  Future<void> removeMember(int projectId, int userId) =>
      (db.delete(db.projectMembers)
            ..where((m) =>
                m.projectId.equals(projectId) & m.userId.equals(userId)))
          .go();

  Future<void> setRole({
    required int projectId,
    required int userId,
    required ProjectRole role,
  }) async {
    await (db.update(db.projectMembers)
          ..where((m) =>
              m.projectId.equals(projectId) & m.userId.equals(userId)))
        .write(ProjectMembersCompanion(role: Value(role)));
  }

  Stream<List<Task>> watchTasks(int projectId) {
    final query = db.select(db.tasks)
      ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }

  Future<double> completionPercent(int projectId) =>
      db.projectCompletionPercent(projectId);
}
