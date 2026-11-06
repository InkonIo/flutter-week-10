// dart | lib/repository/exceptions.dart | flutter | TaskFlow domain-level errors
class DomainException implements Exception {
  final String message;
  const DomainException(this.message);
  @override
  String toString() => message;
}

class DuplicateEmailException extends DomainException {
  const DuplicateEmailException()
      : super('Пользователь с таким email уже существует');
}

class UserHasOpenTasksException extends DomainException {
  const UserHasOpenTasksException()
      : super('Нельзя удалить пользователя — за ним закреплены незавершённые задачи');
}

class NotProjectMemberException extends DomainException {
  const NotProjectMemberException()
      : super('Исполнитель не состоит в проекте');
}

class DuplicateMemberException extends DomainException {
  const DuplicateMemberException()
      : super('Пользователь уже добавлен в этот проект');
}

class TaskLimitExceededException extends DomainException {
  const TaskLimitExceededException()
      : super('У исполнителя уже есть 3 незавершённые задачи с этим дедлайном');
}

class TaskNotFoundException extends DomainException {
  const TaskNotFoundException() : super('Задача не найдена');
}

class NotCommentAuthorException extends DomainException {
  const NotCommentAuthorException()
      : super('Удалить комментарий может только его автор');
}

class NoHistoryToUndoException extends DomainException {
  const NoHistoryToUndoException()
      : super('Нет изменений статуса, которые можно отменить');
}
