import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gapis;

import '../../services/google_auth_service.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/repositories/tasks_repository.dart';
import '../../data/repositories/drive_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/models/app_settings_model.dart';

// ──────────────────────────────────────────────────────
// 1. Auth — Google 계정
// ──────────────────────────────────────────────────────
final authProvider =
    AsyncNotifierProvider<AuthNotifier, GoogleSignInAccount?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<GoogleSignInAccount?> {
  @override
  Future<GoogleSignInAccount?> build() async {
    return await GoogleAuthService.signInSilently();
  }

  Future<void> signIn() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => GoogleAuthService.signIn());
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await GoogleAuthService.signOut();
      return null;
    });
  }
}

// ──────────────────────────────────────────────────────
// 2. Auth HTTP Client
// ──────────────────────────────────────────────────────
final authClientProvider = FutureProvider<gapis.AuthClient?>((ref) async {
  final account = ref.watch(authProvider).value;
  if (account == null) return null;
  return await GoogleAuthService.getAuthClient();
});

// ──────────────────────────────────────────────────────
// 3. Repository Providers
// ──────────────────────────────────────────────────────
final calendarRepositoryProvider = Provider<CalendarRepository?>((ref) {
  final client = ref.watch(authClientProvider).value;
  if (client == null) return null;
  return CalendarRepository(client);
});

final tasksRepositoryProvider = Provider<TasksRepository?>((ref) {
  final client = ref.watch(authClientProvider).value;
  if (client == null) return null;
  return TasksRepository(client);
});

final driveRepositoryProvider = Provider<DriveRepository?>((ref) {
  final client = ref.watch(authClientProvider).value;
  if (client == null) return null;
  return DriveRepository(client);
});

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (_) => SettingsRepository(),
);

// ──────────────────────────────────────────────────────
// 4. Settings ViewModel
// ──────────────────────────────────────────────────────
final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettingsModel>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<AppSettingsModel> {
  @override
  Future<AppSettingsModel> build() async {
    final repo = ref.read(settingsRepositoryProvider);
    return await repo.load();
  }

  Future<void> save(AppSettingsModel settings) async {
    final repo = ref.read(settingsRepositoryProvider);
    state = AsyncData(settings);
    await repo.save(settings);
  }

  Future<void> setThemeColor(Color color) async {
    final current = state.value ?? const AppSettingsModel();
    await save(current.copyWith(themeColor: color));
  }

  Future<void> setStartOnSunday(bool v) async {
    final current = state.value ?? const AppSettingsModel();
    await save(current.copyWith(startOnSunday: v));
  }

  Future<void> setTimezone(String tz) async {
    final current = state.value ?? const AppSettingsModel();
    await save(current.copyWith(timezone: tz));
  }

  Future<void> setLanguage(String lang) async {
    final current = state.value ?? const AppSettingsModel();
    await save(current.copyWith(language: lang));
  }
}

// ──────────────────────────────────────────────────────
// 5. Bottom Navigation Index
// ──────────────────────────────────────────────────────
class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void setIndex(int i) => state = i;
}

final navIndexProvider = NotifierProvider<NavIndexNotifier, int>(NavIndexNotifier.new); // 1 = Calendar (기본)
