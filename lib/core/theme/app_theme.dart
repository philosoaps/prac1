import 'package:flutter/material.dart';

/// seedColor 기반 ThemeData 생성
ThemeData buildAppTheme(Color seedColor) => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      useMaterial3: true,
    );
