// dart | test/performance_test.dart | flutter_test/drift | 4.4: 1k users / 100 projects / 10k tasks, indexed vs not
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterten/database/database.dart';

void main() {
  // Skipped by default — it writes 10k+ rows and is meant to be run on demand
  // (`flutter test test/performance_test.dart --run-skipped`) rather than on
  // every CI run.
  test('поиск/фильтрация/сортировка на 10 000 задач: с индексами и без',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    final rnd = Random(42);

    await db.transaction(() async {
      for (var i = 0; i < 1000; i++) {
        await db.into(db.users).insert(
              UsersCompanion.insert(name: 'User $i', email: 'user$i@test.com'),
            );
      }
      for (var i = 0; i < 100; i++) {
        await db.into(db.projects).insert(
              ProjectsCompanion.insert(name: 'Project $i'),
            );
      }
      for (var i = 0; i < 10000; i++) {
        await db.into(db.tasks).insert(
              TasksCompanion.insert(
                title: 'Task $i ${rnd.nextBool() ? 'urgent' : 'routine'}',
                projectId: 1 + rnd.nextInt(100),
                assigneeId: Value(1 + rnd.nextInt(1000)),
                status: Value(TaskStatus.values[rnd.nextInt(TaskStatus.values.length)]),
                priority:
                    Value(TaskPriority.values[rnd.nextInt(TaskPriority.values.length)]),
                createdAt: Value(DateTime.now().subtract(Duration(days: rnd.nextInt(365)))),
                updatedAt: Value(DateTime.now()),
              ),
            );
      }
    });

    // indexed path: filter on an indexed column (status) + ordered scan.
    final swIndexed = Stopwatch()..start();
    final indexedResult = await (db.select(db.tasks)
          ..where((t) => t.status.equalsValue(TaskStatus.inProgress))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(50))
        .get();
    swIndexed.stop();

    // non-indexed path: LIKE search over free text (no index helps here).
    final swScan = Stopwatch()..start();
    final scanResult = await (db.select(db.tasks)
          ..where((t) => t.title.like('%urgent%'))
          ..limit(50))
        .get();
    swScan.stop();

    // both just need to complete and return rows; the timings are printed
    // for manual comparison since CI hardware varies too much for assertions.
    // ignore: avoid_print
    print('indexed status filter: ${swIndexed.elapsedMilliseconds}ms, ${indexedResult.length} rows');
    // ignore: avoid_print
    print('unindexed LIKE scan:   ${swScan.elapsedMilliseconds}ms, ${scanResult.length} rows');

    expect(indexedResult.length, lessThanOrEqualTo(50));
    expect(scanResult, isNotEmpty);

    await db.close();
  }, skip: 'ресурсоёмкий тест — запускать вручную (10k+ строк)');
}