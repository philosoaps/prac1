import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/tasks_viewmodel.dart';
import '../../../data/models/task_model.dart';

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
            ? _EmptyState(onAdd: () => _showAddTaskDialog(context, ref))
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
        onPressed: () => _showAddTaskDialog(context, ref),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _AddTaskDialog(ref: ref),
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
      child: CheckboxListTile(
        value: task.isCompleted,
        onChanged: (v) =>
            notifier.toggleCompleted(task.id, task.isCompleted),
        title: Text(
          task.title,
          style: TextStyle(
            decoration:
                task.isCompleted ? TextDecoration.lineThrough : null,
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
        secondary: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.grey),
          onPressed: () => notifier.deleteTask(task.id),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.month}/${l.day}';
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
          Icon(Icons.checklist_rounded, size: 64,
              color: Colors.grey.shade300),
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

// ── 할 일 추가 다이얼로그 ─────────────────────────────────
class _AddTaskDialog extends StatefulWidget {
  final WidgetRef ref;
  const _AddTaskDialog({required this.ref});

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 할 일'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '제목 *',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : FilledButton(
                onPressed: _submit,
                child: const Text('추가'),
              ),
      ],
    );
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _loading = true);
    await widget.ref.read(tasksProvider.notifier).createTask(
          title: title,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }
}
