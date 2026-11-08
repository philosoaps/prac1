import 'package:flutter/material.dart';

enum TimeCategory {
  system,
  essential,
  community,
  family,
  personal,
}

extension TimeCategoryDetails on TimeCategory {
  String get labelKo => switch (this) {
        TimeCategory.system => '시스템',
        TimeCategory.essential => '필수',
        TimeCategory.community => '커뮤니티',
        TimeCategory.family => '가족',
        TimeCategory.personal => '개인 시간',
      };

  String get labelEn => switch (this) {
        TimeCategory.system => 'System',
        TimeCategory.essential => 'Essential',
        TimeCategory.community => 'Community',
        TimeCategory.family => 'Family',
        TimeCategory.personal => 'Personal time',
      };

  Color get color => switch (this) {
        TimeCategory.system => const Color(0xFF0072B2),
        TimeCategory.essential => const Color(0xFFE69F00),
        TimeCategory.community => const Color(0xFF009E73),
        TimeCategory.family => const Color(0xFFD55E00),
        TimeCategory.personal => const Color(0xFFCC79A7),
      };

  String get googleColorId => switch (this) {
        TimeCategory.system => '1',
        TimeCategory.essential => '2',
        TimeCategory.community => '3',
        TimeCategory.family => '4',
        TimeCategory.personal => '5',
      };

  static TimeCategory? fromGoogleColorId(String? id) {
    for (final category in TimeCategory.values) {
      if (category.googleColorId == id) return category;
    }
    return null;
  }
}
