import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/life_goal_model.dart';
import '../viewmodels/app_viewmodel.dart';

// ──────────────────────────────────────────────────────
// Life Goal ViewModel
// ──────────────────────────────────────────────────────
final lifeGoalProvider =
    AsyncNotifierProvider.autoDispose<LifeGoalNotifier, LifeGoalModel?>(
  LifeGoalNotifier.new,
);

class LifeGoalNotifier extends AsyncNotifier<LifeGoalModel?> {
  @override
  Future<LifeGoalModel?> build() async {
    final repo = ref.watch(driveRepositoryProvider);
    if (repo == null) return null;
    return await repo.fetchLifeGoal();
  }

  Future<void> save(String content) async {
    final repo = ref.read(driveRepositoryProvider);
    if (repo == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repo.saveLifeGoal(content));
  }
}
