import 'package:googleapis/tasks/v1.dart' as goog_tasks;
import 'package:http/http.dart' as http;

import '../models/task_model.dart';

/// Google Tasks API 접근 레이어
class TasksRepository {
  final goog_tasks.TasksApi _api;

  TasksRepository(http.Client client) : _api = goog_tasks.TasksApi(client);

  Future<List<TaskModel>> fetchTasks({int maxResults = 50}) async {
    final result = await _api.tasks.list(
      '@default',
      maxResults: maxResults,
      showCompleted: true,
      showHidden: true,
    );
    return (result.items ?? []).map(TaskModel.fromGoogleTask).toList();
  }

  Future<TaskModel> createTask({
    required String title,
    String? notes,
    DateTime? due,
  }) async {
    final task = goog_tasks.Task(
      title: title,
      notes: notes,
      due: due?.toUtc().toIso8601String(),
    );
    final created = await _api.tasks.insert(task, '@default');
    return TaskModel.fromGoogleTask(created);
  }

  Future<TaskModel> toggleCompleted({
    required String taskId,
    required bool currentlyCompleted,
  }) async {
    final patch = goog_tasks.Task(
      status: currentlyCompleted ? 'needsAction' : 'completed',
    );
    final updated = await _api.tasks.patch(patch, '@default', taskId);
    return TaskModel.fromGoogleTask(updated);
  }

  Future<void> deleteTask(String taskId) =>
      _api.tasks.delete('@default', taskId);
}
