import 'package:flutter/material.dart';

/// 앱 전역 설정 모델
class AppSettingsModel {
  final Color themeColor;
  final bool startOnSunday; // true = 일요일 시작, false = 월요일 시작
  final String timezone; // e.g. 'Asia/Seoul'
  final String language; // 'ko' or 'en'

  const AppSettingsModel({
    this.themeColor = const Color(0xFF80CBC4), // Mint 기본
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

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    final storedColor = Color(json['themeColorValue'] as int);
    final themeColor = AppThemeColors.palette.any(
      (option) => option.color.toARGB32() == storedColor.toARGB32(),
    )
        ? storedColor
        : AppThemeColors.palette.first.color;
    return AppSettingsModel(
      themeColor: themeColor,
      startOnSunday: json['startOnSunday'] as bool,
      timezone: json['timezone'] as String,
      language: json['language'] as String,
    );
  }
}

/// 테마 선택에 쓸 9가지 색상 (3×3 그리드)
class AppThemeColors {
  static const List<({Color color, String label})> palette = [
    (color: Color(0xFF80CBC4), label: 'Mint'),
    (color: Color(0xFF90CAF9), label: 'Sky'),
    (color: Color(0xFFF48FB1), label: 'Blush'),
    (color: Color(0xFFFFCC80), label: 'Peach'),
    (color: Color(0xFFBCAAA4), label: 'Sand'),
    (color: Color(0xFFA5D6A7), label: 'Sage'),
    (color: Color(0xFFCE93D8), label: 'Lilac'),
    (color: Color(0xFF9FA8DA), label: 'Lavender'),
    (color: Color(0xFFE6EE9C), label: 'Lime'),
  ];
}
