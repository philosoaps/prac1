import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/task_model.dart';
import '../viewmodels/app_viewmodel.dart';

// ──────────────────────────────────────────────────────
// Tasks ViewModel
// ──────────────────────────────────────────────────────
final tasksProvider =
    AsyncNotifierProvider.autoDispose<TasksNotifier, List<TaskModel>>(
  TasksNotifier.new,
);

class TasksNotifier extends AsyncNotifier<List<TaskModel>> {
  @override
  Future<List<TaskModel>> build() async {
    final repo = ref.watch(tasksRepositoryProvider);
    if (repo == null) return [];
    return await repo.fetchTasks();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(tasksRepositoryProvider);
      if (repo == null) return [];
      return await repo.fetchTasks();
    });
  }

  Future<void> createTask({required String title, String? notes}) async {
    final repo = ref.read(tasksRepositoryProvider);
    if (repo == null) return;
    final due = DateTime.now().add(const Duration(days: 1));
    await repo.createTask(title: title, notes: notes, due: due);
    await refresh();
  }

  Future<void> toggleCompleted(String taskId, bool currentlyCompleted) async {
    final repo = ref.read(tasksRepositoryProvider);
    if (repo == null) return;
    await repo.toggleCompleted(
        taskId: taskId, currentlyCompleted: currentlyCompleted);
    await refresh();
  }

  Future<void> deleteTask(String taskId) async {
    final repo = ref.read(tasksRepositoryProvider);
    if (repo == null) return;
    await repo.deleteTask(taskId);
    await refresh();
  }
}
