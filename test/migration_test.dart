// dart | test/migration_test.dart | flutter_test/drift | v1 -> v2 migration (adds tasks.priority)
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:flutterten/database/database.dart';

/// builds a raw sqlite db matching the *v1* schema (tasks has no `priority`
/// column) with `user_version = 1`, then opens it through AppDatabase to
/// make sure the real onUpgrade() path runs.
sqlite3.Database _buildV1Database() {
  final raw = sqlite3.sqlite3.openInMemory();
  raw.execute('''
    CREATE TABLE users (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      registered_at INTEGER NOT NULL
    );
    CREATE TABLE projects (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL,
      completed_at INTEGER,
      status TEXT NOT NULL DEFAULT 'active'
    );
    CREATE TABLE project_members (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role TEXT NOT NULL DEFAULT 'member',
      UNIQUE(project_id, user_id)
    );
    CREATE TABLE tasks (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
      assignee_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      status TEXT NOT NULL DEFAULT 'todo',
      deadline INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    );
    CREATE TABLE task_history (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      previous_status TEXT,
      new_status TEXT NOT NULL,
      changed_by INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      changed_at INTEGER NOT NULL
    );
    CREATE TABLE comments (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      author_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      text TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE attachments (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
      file_name TEXT NOT NULL,
      file_path TEXT NOT NULL,
      added_at INTEGER NOT NULL
    );
  ''');

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  raw.execute(
    "INSERT INTO users (name, email, registered_at) VALUES ('Old User', 'old@test.com', $now)",
  );
  raw.execute(
    "INSERT INTO projects (name, created_at, status) VALUES ('Legacy project', $now, 'active')",
  );
  raw.execute(
    "INSERT INTO tasks (title, project_id, status, created_at, updated_at) "
    "VALUES ('Legacy task', 1, 'todo', $now, $now)",
  );
  raw.userVersion = 1;
  return raw;
}

void main() {
  test('миграция v1 -> v2 добавляет priority и не теряет данные', () async {
    final raw = _buildV1Database();
    final db = AppDatabase(NativeDatabase.opened(raw));

    // opening the db runs MigrationStrategy.onUpgrade(1, 2) under the hood.
    final allTasks = await db.select(db.tasks).get();

    expect(allTasks, hasLength(1), reason: 'существующая запись не потеряна');
    expect(allTasks.first.title, 'Legacy task');
    expect(allTasks.first.priority, TaskPriority.medium,
        reason: 'бэкфилл выставил medium для старых записей');

    final allUsers = await db.select(db.users).get();
    expect(allUsers, hasLength(1));

    await db.close();
  });
}