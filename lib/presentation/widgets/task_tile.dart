// dart | lib/presentation/widgets/task_tile.dart | flutter | compact task row
import 'package:flutter/material.dart';
import '../../database/database.dart';
import '../screens/task_detail_screen.dart';

Color priorityColor(TaskPriority p) {
  switch (p) {
    case TaskPriority.low:
      return Colors.blueGrey;
    case TaskPriority.medium:
      return Colors.blue;
    case TaskPriority.high:
      return Colors.orange;
    case TaskPriority.critical:
      return Colors.red;
  }
}

String statusLabel(TaskStatus s) {
  switch (s) {
    case TaskStatus.todo:
      return 'ожидает';
    case TaskStatus.inProgress:
      return 'в работе';
    case TaskStatus.done:
      return 'готово';
    case TaskStatus.cancelled:
      return 'отменено';
  }
}

class TaskTile extends StatelessWidget {
  final Task task;
  const TaskTile({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final overdue = task.deadline != null &&
        task.deadline!.isBefore(DateTime.now()) &&
        task.status != TaskStatus.done &&
        task.status != TaskStatus.cancelled;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: priorityColor(task.priority),
        child: Text(task.priority.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
      title: Text(task.title),
      subtitle: Text(
        '${statusLabel(task.status)}'
        '${task.deadline != null ? ' · дедлайн ${task.deadline!.toLocal().toString().split(' ').first}' : ''}',
        style: TextStyle(color: overdue ? Colors.red : null),
      ),
      trailing: overdue ? const Icon(Icons.warning, color: Colors.red) : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
      ),
    );
  }
}
