// dart | lib/repository/user_repository.dart | flutter/drift | user CRUD + membership rules
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../database/database.dart';
import 'exceptions.dart';

class UserRepository {
  final AppDatabase db;
  const UserRepository(this.db);

  Stream<List<User>> watchAll() => db.select(db.users).watch();

  Future<User?> getById(int id) =>
      (db.select(db.users)..where((u) => u.id.equals(id))).getSingleOrNull();

  Future<User> create({required String name, required String email}) async {
    try {
      final id = await db.into(db.users).insert(
            UsersCompanion.insert(name: name, email: email),
          );
      return (await getById(id))!;
    } on SqliteException catch (e) {
      if (e.extendedResultCode == 2067 || e.message.contains('UNIQUE')) {
        throw const DuplicateEmailException();
      }
      rethrow;
    }
  }

  Future<void> update(User user) async {
    try {
      await db.update(db.users).replace(user);
    } on SqliteException catch (e) {
      if (e.extendedResultCode == 2067 || e.message.contains('UNIQUE')) {
        throw const DuplicateEmailException();
      }
      rethrow;
    }
  }

  /// deletion is blocked while the user still has unfinished tasks assigned.
  Future<void> delete(int userId) async {
    final openTasks = await (db.select(db.tasks)
          ..where((t) =>
              t.assigneeId.equals(userId) &
              t.deletedAt.isNull() &
              (t.status.equalsValue(TaskStatus.todo) |
                  t.status.equalsValue(TaskStatus.inProgress))))
        .get();
    if (openTasks.isNotEmpty) {
      throw const UserHasOpenTasksException();
    }
    await (db.delete(db.users)..where((u) => u.id.equals(userId))).go();
  }

  Stream<List<Task>> watchTasksForUser(int userId) {
    final query = db.select(db.tasks)
      ..where((t) => t.assigneeId.equals(userId) & t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }
}
