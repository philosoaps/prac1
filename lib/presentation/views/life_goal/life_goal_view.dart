import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/life_goal_viewmodel.dart';

/// Life Goal 입력/저장 화면
class LifeGoalView extends ConsumerStatefulWidget {
  const LifeGoalView({super.key});

  @override
  ConsumerState<LifeGoalView> createState() => _LifeGoalViewState();
}

class _LifeGoalViewState extends ConsumerState<LifeGoalView> {
  final _controller = TextEditingController();
  bool _dirty = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goalAsync = ref.watch(lifeGoalProvider);
    final notifier = ref.read(lifeGoalProvider.notifier);

    // 처음 로드됐을 때 텍스트 채우기
    ref.listen(lifeGoalProvider, (prev, next) {
      if (prev?.value == null && next.value != null && !_dirty) {
        _controller.text = next.value?.content ?? '';
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Goal'),
        actions: [
          if (goalAsync.isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_rounded),
              tooltip: '저장',
              onPressed: () async {
                await notifier.save(_controller.text.trim());
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Life Goal이 저장되었습니다'),
                    duration: Duration(seconds: 2),
                  ),
                );
                setState(() => _dirty = false);
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '나의 삶의 목표',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '인생에서 이루고 싶은 가장 중요한 목표를 적어보세요.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: '여기에 목표를 입력하세요...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: const TextStyle(fontSize: 15, height: 1.6),
                onChanged: (_) => setState(() => _dirty = true),
              ),
            ),
            const SizedBox(height: 12),
            // 마지막 저장 시각
            if (goalAsync.value?.savedAt != null)
              Text(
                '마지막 저장: ${_formatDate(goalAsync.value!.savedAt)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade500),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.save_rounded),
                label: const Text('저장'),
                onPressed: goalAsync.isLoading
                    ? null
                    : () async {
                        await notifier.save(_controller.text.trim());
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Life Goal이 저장되었습니다'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        setState(() => _dirty = false);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
