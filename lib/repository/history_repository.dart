// dart | lib/repository/history_repository.dart | flutter/drift | read-only task history access
import 'package:drift/drift.dart';
import '../database/database.dart';

class HistoryRepository {
  final AppDatabase db;
  const HistoryRepository(this.db);

  Stream<List<TaskHistoryEntry>> watchForTask(int taskId) {
    final q = db.select(db.taskHistory)
      ..where((h) => h.taskId.equals(taskId))
      ..orderBy([(h) => OrderingTerm.desc(h.changedAt)]);
    return q.watch();
  }

  Future<List<TaskHistoryEntry>> getForTask(int taskId) =>
      (db.select(db.taskHistory)
            ..where((h) => h.taskId.equals(taskId))
            ..orderBy([(h) => OrderingTerm.desc(h.changedAt)]))
          .get();
}
