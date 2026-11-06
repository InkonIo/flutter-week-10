// dart | lib/repository/attachment_repository.dart | flutter/drift | task file attachments (path only)
import 'package:drift/drift.dart';
import '../database/database.dart';

class AttachmentRepository {
  final AppDatabase db;
  const AttachmentRepository(this.db);

  Stream<List<Attachment>> watchForTask(int taskId) {
    final q = db.select(db.attachments)
      ..where((a) => a.taskId.equals(taskId))
      ..orderBy([(a) => OrderingTerm.desc(a.addedAt)]);
    return q.watch();
  }

  /// stores only the file name and local path — never the file bytes.
  Future<Attachment> add({
    required int taskId,
    required String fileName,
    required String filePath,
  }) async {
    final id = await db.into(db.attachments).insert(
          AttachmentsCompanion.insert(
            taskId: taskId,
            fileName: fileName,
            filePath: filePath,
          ),
        );
    return (db.select(db.attachments)..where((a) => a.id.equals(id))).getSingle();
  }

  Future<void> delete(int attachmentId) =>
      (db.delete(db.attachments)..where((a) => a.id.equals(attachmentId))).go();
}
