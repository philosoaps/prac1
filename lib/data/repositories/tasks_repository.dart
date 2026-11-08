import 'package:googleapis/tasks/v1.dart' as goog_tasks;
import 'package:http/http.dart' as http;

import '../models/task_model.dart';

/// Google Tasks API 접근 레이어
class TasksRepository {
  final goog_tasks.TasksApi _api;

  TasksRepository(http.Client client) : _api = goog_tasks.TasksApi(client);

  Future<List<TaskModel>> fetchTasks({int maxResults = 100}) async {
    final tasks = <TaskModel>[];
    String? pageToken;
    do {
      final result = await _api.tasks.list(
        '@default',
        maxResults: maxResults.clamp(1, 100),
        pageToken: pageToken,
        showCompleted: true,
        showHidden: true,
      );
      tasks.addAll((result.items ?? []).map(TaskModel.fromGoogleTask));
      pageToken = result.nextPageToken;
    } while (pageToken != null);
    return tasks;
  }

  Future<TaskModel> createTask({
    required String title,
    String? notes,
    DateTime? due,
  }) async {
    final task = goog_tasks.Task(
      title: title,
      notes: notes,
      due: due == null
          ? null
          : DateTime.utc(due.year, due.month, due.day).toIso8601String(),
    );
    final created = await _api.tasks.insert(task, '@default');
    return TaskModel.fromGoogleTask(created);
  }

  Future<TaskModel> updateTask({
    required String taskId,
    required String title,
    String? notes,
    DateTime? due,
  }) async {
    final updated = await _api.tasks.patch(
      goog_tasks.Task(
        title: title,
        notes: notes,
        due: due == null
            ? null
            : DateTime.utc(due.year, due.month, due.day).toIso8601String(),
      ),
      '@default',
      taskId,
    );
    return TaskModel.fromGoogleTask(updated);
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
