import 'package:googleapis/tasks/v1.dart' as goog_tasks;

/// Google Tasks Task를 감싸는 도메인 모델
class TaskModel {
  final String id;
  final String title;
  final String? notes;
  final bool isCompleted;
  final DateTime? due;

  const TaskModel({
    required this.id,
    required this.title,
    this.notes,
    this.isCompleted = false,
    this.due,
  });

  factory TaskModel.fromGoogleTask(goog_tasks.Task task) => TaskModel(
        id: task.id ?? '',
        title: task.title ?? '(제목 없음)',
        notes: task.notes,
        isCompleted: task.status == 'completed',
        due: task.due != null ? DateTime.tryParse(task.due!) : null,
      );

  TaskModel copyWith({
    String? id,
    String? title,
    String? notes,
    bool? isCompleted,
    DateTime? due,
  }) =>
      TaskModel(
        id: id ?? this.id,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        isCompleted: isCompleted ?? this.isCompleted,
        due: due ?? this.due,
      );
}
