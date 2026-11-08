import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings_model.dart';

/// 앱 설정을 SharedPreferences에 저장/불러오는 레이어
class SettingsRepository {
  static const String _key = 'app_settings';

  Future<AppSettingsModel> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const AppSettingsModel();
    try {
      return AppSettingsModel.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettingsModel();
    }
  }

  Future<void> save(AppSettingsModel settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
