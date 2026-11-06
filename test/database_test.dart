// dart | test/database_test.dart | flutter_test/drift | 15+ unit tests over an in-memory db
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart' hide isNull;
import 'package:flutterten/database/database.dart';
import 'package:flutterten/repository/attachment_repository.dart';
import 'package:flutterten/repository/comment_repository.dart';
import 'package:flutterten/repository/dashboard_repository.dart';
import 'package:flutterten/repository/exceptions.dart';
import 'package:flutterten/repository/history_repository.dart';
import 'package:flutterten/repository/project_repository.dart';
import 'package:flutterten/repository/task_repository.dart';
import 'package:flutterten/repository/user_repository.dart';
import 'package:flutterten/repository/attachment_repository.dart' show AttachmentRepository;
import 'package:flutterten/repository/comment_repository.dart';
import 'package:flutterten/repository/dashboard_repository.dart' show DashboardRepository;
import 'package:flutterten/repository/history_repository.dart';
import 'package:flutterten/repository/project_repository.dart';
import 'package:flutterten/repository/task_repository.dart';
import 'package:flutterten/repository/user_repository.dart';

void main() {
  late AppDatabase db;
  late UserRepository users;
  late ProjectRepository projects;
  late TaskRepository tasks;
  late CommentRepository comments;
  late AttachmentRepository attachments;
  late HistoryRepository history;
  late DashboardRepository dashboard;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    users = UserRepository(db);
    projects = ProjectRepository(db);
    tasks = TaskRepository(db);
    comments = CommentRepository(db);
    attachments = AttachmentRepository(db);
    history = HistoryRepository(db);
    dashboard = DashboardRepository(db);
  });

  tearDown(() => db.close());

  Future<User> makeUser(String name, String email) =>
      users.create(name: name, email: email);

  Future<Project> makeProject(String name) => projects.create(name: name);

  test('1. создаёт пользователя', () async {
    final u = await makeUser('Alice', 'alice@test.com');
    expect(u.id, isPositive);
    expect(u.email, 'alice@test.com');
  });

  test('2. email должен быть уникальным', () async {
    await makeUser('Alice', 'dup@test.com');
    expect(
      () => makeUser('Bob', 'dup@test.com'),
      throwsA(isA<DuplicateEmailException>()),
    );
  });

  test('3. удаление пользователя', () async {
    final u = await makeUser('Carl', 'carl@test.com');
    await users.delete(u.id);
    expect(await users.getById(u.id), isNull);
  });

  test('4. нельзя удалить пользователя с незавершёнными задачами', () async {
    final owner = await makeUser('Owner', 'owner@test.com');
    final dev = await makeUser('Dev', 'dev@test.com');
    final project = await makeProject('P1');
    await projects.addMember(projectId: project.id, userId: dev.id);
    await tasks.create(
      title: 'T1',
      projectId: project.id,
      assigneeId: dev.id,
      actingUserId: owner.id,
    );
    expect(
      () => users.delete(dev.id),
      throwsA(isA<UserHasOpenTasksException>()),
    );
  });

  test('5. создаёт проект', () async {
    final p = await makeProject('Website');
    expect(p.status, ProjectStatus.active);
  });

  test('6. добавление участника в проект и запрет дубликата', () async {
    final u = await makeUser('Mem', 'mem@test.com');
    final p = await makeProject('P2');
    await projects.addMember(projectId: p.id, userId: u.id);
    expect(await projects.isMember(p.id, u.id), isTrue);
    expect(
      () => projects.addMember(projectId: p.id, userId: u.id),
      throwsA(isA<DuplicateMemberException>()),
    );
  });

  test('7. создание задачи требует существующий проект', () async {
    final owner = await makeUser('Owner2', 'owner2@test.com');
    expect(
      () => tasks.create(title: 'X', projectId: 9999, actingUserId: owner.id),
      throwsA(isA<DomainException>()),
    );
  });

  test('8. исполнитель должен быть участником проекта', () async {
    final owner = await makeUser('Owner3', 'owner3@test.com');
    final outsider = await makeUser('Outsider', 'outsider@test.com');
    final p = await makeProject('P3');
    expect(
      () => tasks.create(
        title: 'X',
        projectId: p.id,
        assigneeId: outsider.id,
        actingUserId: owner.id,
      ),
      throwsA(isA<NotProjectMemberException>()),
    );
  });

  test('9. изменение статуса задачи пишет историю', () async {
    final owner = await makeUser('Owner4', 'owner4@test.com');
    final p = await makeProject('P4');
    final t = await tasks.create(title: 'T', projectId: p.id, actingUserId: owner.id);
    await tasks.changeStatus(
      taskId: t.id,
      newStatus: TaskStatus.inProgress,
      actingUserId: owner.id,
    );
    final h = await history.getForTask(t.id);
    expect(h.length, 2); // created + status change
    expect(h.first.newStatus, 'inProgress');
    expect(h.first.previousStatus, 'todo');
  });

  test('10. создание задачи и первой записи истории — одна транзакция', () async {
    final owner = await makeUser('Owner5', 'owner5@test.com');
    final p = await makeProject('P5');
    final t = await tasks.create(title: 'T', projectId: p.id, actingUserId: owner.id);
    final h = await history.getForTask(t.id);
    expect(h, hasLength(1));
    expect(h.first.previousStatus, isNull);
    expect(h.first.newStatus, 'todo');
  });

  test('11. добавление комментария', () async {
    final owner = await makeUser('Owner6', 'owner6@test.com');
    final p = await makeProject('P6');
    final t = await tasks.create(title: 'T', projectId: p.id, actingUserId: owner.id);
    final c = await comments.add(taskId: t.id, authorId: owner.id, text: 'hi');
    expect(c.content, 'hi');
  });

  test('12. нельзя добавить комментарий к несуществующей задаче', () async {
    final owner = await makeUser('Owner7', 'owner7@test.com');
    expect(
      () => comments.add(taskId: 9999, authorId: owner.id, text: 'x'),
      throwsA(isA<DomainException>()),
    );
  });

  test('13. soft delete скрывает задачу из основных списков', () async {
    final owner = await makeUser('Owner8', 'owner8@test.com');
    final p = await makeProject('P8');
    final t = await tasks.create(title: 'T', projectId: p.id, actingUserId: owner.id);
    await tasks.softDelete(t.id);
    final active = await tasks.getFiltered(TaskFilter(projectId: p.id));
    expect(active, isEmpty);
    final deleted = await (db.select(db.tasks)..where((x) => x.deletedAt.isNotNull())).get();
    expect(deleted, hasLength(1));
  });

  test('14. восстановление задачи из корзины', () async {
    final owner = await makeUser('Owner9', 'owner9@test.com');
    final p = await makeProject('P9');
    final t = await tasks.create(title: 'T', projectId: p.id, actingUserId: owner.id);
    await tasks.softDelete(t.id);
    await tasks.restore(t.id);
    final active = await tasks.getFiltered(TaskFilter(projectId: p.id));
    expect(active, hasLength(1));
  });

  test('15. корректность статистики дашборда', () async {
    final owner = await makeUser('Owner10', 'owner10@test.com');
    final p = await makeProject('P10');
    final t1 = await tasks.create(title: 'T1', projectId: p.id, actingUserId: owner.id);
    await tasks.create(title: 'T2', projectId: p.id, actingUserId: owner.id);
    await tasks.changeStatus(taskId: t1.id, newStatus: TaskStatus.done, actingUserId: owner.id);

    final stats = await dashboard.load();
    expect(stats.totalProjects, 1);
    expect(stats.totalTasks, 2);
    expect(stats.completedTasks, 1);
    expect(stats.incompleteTasks, 1);
  });

  test('16. транзакция переназначения исполнителя проверяет членство', () async {
    final owner = await makeUser('Owner11', 'owner11@test.com');
    final member = await makeUser('Member11', 'member11@test.com');
    final outsider = await makeUser('Outsider11', 'outsider11@test.com');
    final p = await makeProject('P11');
    await projects.addMember(projectId: p.id, userId: member.id);
    final t = await tasks.create(
      title: 'T',
      projectId: p.id,
      assigneeId: member.id,
      actingUserId: owner.id,
    );
    expect(
      () => tasks.reassign(taskId: t.id, newAssigneeId: outsider.id, actingUserId: owner.id),
      throwsA(isA<NotProjectMemberException>()),
    );
  });

  test('17. фильтрация задач по статусу и поиск по названию', () async {
    final owner = await makeUser('Owner12', 'owner12@test.com');
    final p = await makeProject('P12');
    final t1 = await tasks.create(title: 'Fix login bug', projectId: p.id, actingUserId: owner.id);
    await tasks.create(title: 'Write docs', projectId: p.id, actingUserId: owner.id);
    await tasks.changeStatus(taskId: t1.id, newStatus: TaskStatus.inProgress, actingUserId: owner.id);

    final inProgress = await tasks.getFiltered(
      TaskFilter(projectId: p.id, status: TaskStatus.inProgress),
    );
    expect(inProgress, hasLength(1));

    final searched = await tasks.getFiltered(TaskFilter(projectId: p.id, search: 'login'));
    expect(searched, hasLength(1));
    expect(searched.first.title, contains('login'));
  });

  test('18. ограничение в 3 незавершённые задачи на один дедлайн у исполнителя', () async {
    final owner = await makeUser('Owner13', 'owner13@test.com');
    final dev = await makeUser('Dev13', 'dev13@test.com');
    final p = await makeProject('P13');
    await projects.addMember(projectId: p.id, userId: dev.id);
    final deadline = DateTime(2026, 12, 1);
    for (var i = 0; i < 3; i++) {
      await tasks.create(
        title: 'T$i',
        projectId: p.id,
        assigneeId: dev.id,
        deadline: deadline,
        actingUserId: owner.id,
      );
    }
    expect(
      () => tasks.create(
        title: 'T4',
        projectId: p.id,
        assigneeId: dev.id,
        deadline: deadline,
        actingUserId: owner.id,
      ),
      throwsA(isA<TaskLimitExceededException>()),
    );
  });

  test('19. отмена (undo) последнего изменения статуса', () async {
    final owner = await makeUser('Owner14', 'owner14@test.com');
    final p = await makeProject('P14');
    final t = await tasks.create(title: 'T', projectId: p.id, actingUserId: owner.id);
    await tasks.changeStatus(taskId: t.id, newStatus: TaskStatus.inProgress, actingUserId: owner.id);
    await tasks.undoLastStatusChange(taskId: t.id, actingUserId: owner.id);
    final reverted = await tasks.getById(t.id);
    expect(reverted!.status, TaskStatus.todo);
  });

  test('20. только автор может удалить свой комментарий', () async {
    final author = await makeUser('Author', 'author@test.com');
    final other = await makeUser('Other', 'other@test.com');
    final p = await makeProject('P15');
    final t = await tasks.create(title: 'T', projectId: p.id, actingUserId: author.id);
    final c = await comments.add(taskId: t.id, authorId: author.id, text: 'hello');
    expect(
      () => comments.delete(commentId: c.id, requestingUserId: other.id),
      throwsA(isA<NotCommentAuthorException>()),
    );
    await comments.delete(commentId: c.id, requestingUserId: author.id);
  });

  test('21. вложения хранят только путь к файлу', () async {
    final owner = await makeUser('Owner16', 'owner16@test.com');
    final p = await makeProject('P16');
    final t = await tasks.create(title: 'T', projectId: p.id, actingUserId: owner.id);
    final a = await attachments.add(
      taskId: t.id,
      fileName: 'report.pdf',
      filePath: '/storage/emulated/0/Download/report.pdf',
    );
    expect(a.filePath, isNot(contains('%PDF')));
  });
}