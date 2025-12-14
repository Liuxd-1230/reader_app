import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. 主题定义 (保持不变)
class ReaderTheme {
  final Color bgColor;
  final Color textColor;
  const ReaderTheme(this.bgColor, this.textColor);
}

final List<ReaderTheme> themes = [
  const ReaderTheme(Color(0xFFF7F1E3), Colors.black87), // 羊皮纸
  const ReaderTheme(Colors.white, Colors.black),        // 纯白
  const ReaderTheme(Color(0xFFC8E6C9), Colors.black87), // 护眼绿
  const ReaderTheme(Color(0xFF1A1A1A), Color(0xFFB0B0B0)), // 深色模式
];

// 2. 状态数据类 (保持不变)
class ReadingSettings {
  final double fontSize;
  final int themeIndex;

  ReadingSettings({this.fontSize = 18.0, this.themeIndex = 0});

  ReaderTheme get currentTheme => themes[themeIndex];

  ReadingSettings copyWith({double? fontSize, int? themeIndex}) {
    return ReadingSettings(
      fontSize: fontSize ?? this.fontSize,
      themeIndex: themeIndex ?? this.themeIndex,
    );
  }
}

// 3. 【关键修改】使用 Notifier (Riverpod 2.0 新标准)
class ReadingSettingsNotifier extends Notifier<ReadingSettings> {
  @override
  ReadingSettings build() {
    // 初始化状态
    return ReadingSettings();
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
  }

  void setTheme(int index) {
    state = state.copyWith(themeIndex: index);
  }
}

// 4. 【关键修改】使用 NotifierProvider
final readingSettingsProvider =
NotifierProvider<ReadingSettingsNotifier, ReadingSettings>(() {
  return ReadingSettingsNotifier();
});