import 'package:flutter/material.dart';

/// 앱 전역 설정 모델
class AppSettingsModel {
  final Color themeColor;
  final bool startOnSunday; // true = 일요일 시작, false = 월요일 시작
  final String timezone;    // e.g. 'Asia/Seoul'
  final String language;    // 'ko' or 'en'

  const AppSettingsModel({
    this.themeColor = const Color(0xFF3F51B5), // Indigo 기본
    this.startOnSunday = true,
    this.timezone = 'Asia/Seoul',
    this.language = 'ko',
  });

  AppSettingsModel copyWith({
    Color? themeColor,
    bool? startOnSunday,
    String? timezone,
    String? language,
  }) =>
      AppSettingsModel(
        themeColor: themeColor ?? this.themeColor,
        startOnSunday: startOnSunday ?? this.startOnSunday,
        timezone: timezone ?? this.timezone,
        language: language ?? this.language,
      );

  Map<String, dynamic> toJson() => {
        'themeColorValue': themeColor.toARGB32(),
        'startOnSunday': startOnSunday,
        'timezone': timezone,
        'language': language,
      };

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) =>
      AppSettingsModel(
        themeColor: Color(json['themeColorValue'] as int),
        startOnSunday: json['startOnSunday'] as bool,
        timezone: json['timezone'] as String,
        language: json['language'] as String,
      );
}

/// 테마 선택에 쓸 9가지 색상 (3×3 그리드)
class AppThemeColors {
  static const List<({Color color, String label})> palette = [
    (color: Color(0xFF3F51B5), label: 'Indigo'),
    (color: Color(0xFF9C27B0), label: 'Purple'),
    (color: Color(0xFF009688), label: 'Teal'),
    (color: Color(0xFFFF5722), label: 'Deep Orange'),
    (color: Color(0xFFF44336), label: 'Red'),
    (color: Color(0xFF4CAF50), label: 'Green'),
    (color: Color(0xFFE91E63), label: 'Pink'),
    (color: Color(0xFF795548), label: 'Brown'),
    (color: Color(0xFF607D8B), label: 'Blue Grey'),
  ];
}
