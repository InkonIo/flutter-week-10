// dart | lib/repository/comment_repository.dart | flutter/drift | task comments
import 'package:drift/drift.dart';
import '../database/database.dart';
import 'exceptions.dart';

class CommentRepository {
  final AppDatabase db;
  const CommentRepository(this.db);

  Stream<List<Comment>> watchForTask(int taskId) {
    final q = db.select(db.comments)
      ..where((c) => c.taskId.equals(taskId))
      ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]);
    return q.watch();
  }

  Future<Comment> add({
    required int taskId,
    required int authorId,
    required String text,
  }) async {
    final task = await (db.select(db.tasks)..where((t) => t.id.equals(taskId)))
        .getSingleOrNull();
    if (task == null) {
      throw const DomainException('Нельзя добавить комментарий к несуществующей задаче');
    }
    final id = await db.into(db.comments).insert(
          CommentsCompanion.insert(taskId: taskId, authorId: authorId, content: text),
        );
    return (db.select(db.comments)..where((c) => c.id.equals(id))).getSingle();
  }

  /// only the comment's own author may delete it.
  Future<void> delete({required int commentId, required int requestingUserId}) async {
    final comment = await (db.select(db.comments)
          ..where((c) => c.id.equals(commentId)))
        .getSingleOrNull();
    if (comment == null) return;
    if (comment.authorId != requestingUserId) {
      throw const NotCommentAuthorException();
    }
    await (db.delete(db.comments)..where((c) => c.id.equals(commentId))).go();
  }
}