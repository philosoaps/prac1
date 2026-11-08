import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_timezone.dart';
import '../../viewmodels/app_viewmodel.dart';
import '../../viewmodels/tasks_viewmodel.dart';
import '../../../data/models/task_model.dart';
import '../../widgets/schedule_task_composer.dart';

/// Google Tasks 화면
class TasksView extends ConsumerWidget {
  const TasksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('오류 발생: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(tasksProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (tasks) => tasks.isEmpty
            ? _EmptyState(onAdd: () => _showEntryMenu(context, ref))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(tasksProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: tasks.length,
                  itemBuilder: (ctx, i) => _TaskTile(task: tasks[i]),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'tasks_fab',
        child: const Icon(Icons.add),
        onPressed: () => _showEntryMenu(context, ref),
      ),
    );
  }

  void _showEntryMenu(BuildContext context, WidgetRef ref) {
    final timezone = ref.read(settingsProvider).value?.timezone ?? 'Asia/Seoul';
    showScheduleTaskEntryMenu(
      context: context,
      ref: ref,
      initialDate: nowInTimezone(timezone),
      timezone: timezone,
    );
  }
}

// ── 개별 Task 타일 ──────────────────────────────────────
class _TaskTile extends ConsumerWidget {
  final TaskModel task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tasksProvider.notifier);
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('삭제 확인'),
            content: const Text('이 할 일을 삭제할까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('삭제'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => notifier.deleteTask(task.id),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (_) => notifier.toggleCompleted(task.id, task.isCompleted),
        ),
        onTap: () {
          final timezone =
              ref.read(settingsProvider).value?.timezone ?? 'Asia/Seoul';
          showDialog<void>(
            context: context,
            builder: (_) => ScheduleTaskComposer(
              initialDate: task.due ?? nowInTimezone(timezone),
              timezone: timezone,
              initialType: ScheduleTaskEntryType.task,
              task: task,
            ),
          );
        },
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: task.notes != null
            ? Text(
                task.notes!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey),
              )
            : (task.due != null
                ? Text(
                    '기한: ${_formatDate(task.due!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  )
                : null),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.grey),
          onPressed: () => notifier.deleteTask(task.id),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final due = dt.toUtc();
    return '${due.month}/${due.day}';
  }
}

// ── 빈 상태 ──────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('할 일이 없습니다',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('할 일 추가'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
