
# TaskFlow

Flutter + SQLite (Drift). Офлайн-first менеджер проектов/задач.

## Запуск

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # генерирует lib/database/database.g.dart
flutter run
```

## Тесты

```bash
flutter test                                   # все, кроме performance_test (он skip по умолчанию)
flutter test test/performance_test.dart --run-skipped
```

## Структура

```
lib/
  database/database.dart        — таблицы, enum-конвертеры, миграции (v1→v2: +priority), raw SQL для статистики
  repository/                   — вся работа с БД только отсюда (транзакции, бизнес-правила)
  providers/providers.dart      — Riverpod: Database/Repository providers + watch()-стримы на экраны
  presentation/screens/         — UI
  presentation/widgets/
  main.dart
test/
  database_test.dart            — 21 unit-тест (CRUD, уникальность, транзакции, soft delete, undo, статистика...)
  migration_test.dart           — проверка миграции v1→v2 на сырой sqlite-базе
  performance_test.dart         — 1000 users / 100 projects / 10000 tasks, indexed vs unindexed (ручной запуск)
```

`database.g.dart` не входит в комплект — это сгенерированный файл, `build_runner` создаёт его из `database.dart`.
