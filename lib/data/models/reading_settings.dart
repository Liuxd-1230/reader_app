import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderTheme {
  final String name;
  final Color bgColor;
  final Color textColor;
  final Color menuColor; // 菜单背景色

  const ReaderTheme(this.name, this.bgColor, this.textColor, this.menuColor);
}

final List<ReaderTheme> themes = [
  const ReaderTheme("羊皮纸", Color(0xFFFAF9DE), Colors.black87, Color(0xDDFAF9DE)),
  const ReaderTheme("护眼绿", Color(0xFFC8E6C9), Colors.black87, Color(0xDDC8E6C9)),
  const ReaderTheme("极简白", Color(0xFFFFFFFF), Colors.black87, Color(0xDDFFFFFF)),
  const ReaderTheme("深空灰", Color(0xFF1C1C1E), Color(0xFFE5E5E5), Color(0xDD2C2C2E)),
];

class ReadingSettings {
  final double fontSize;
  final int themeIndex;
  final String? deepSeekApiKey;
  final double brightness; // 1.0 = 最亮, 0.2 = 最暗

  const ReadingSettings({
    this.fontSize = 18.0,
    this.themeIndex = 0,
    this.deepSeekApiKey,
    this.brightness = 1.0,
  });

  ReaderTheme get currentTheme => themes[themeIndex];

  ReadingSettings copyWith({double? fontSize, int? themeIndex, String? deepSeekApiKey, double? brightness}) {
    return ReadingSettings(
      fontSize: fontSize ?? this.fontSize,
      themeIndex: themeIndex ?? this.themeIndex,
      deepSeekApiKey: deepSeekApiKey ?? this.deepSeekApiKey,
      brightness: brightness ?? this.brightness,
    );
  }
}

class ReadingSettingsNotifier extends Notifier<ReadingSettings> {
  @override
  ReadingSettings build() => const ReadingSettings();

  void setFontSize(double size) => state = state.copyWith(fontSize: size);
  void setTheme(int index) => state = state.copyWith(themeIndex: index);
  void setApiKey(String key) => state = state.copyWith(deepSeekApiKey: key);
  void setBrightness(double b) => state = state.copyWith(brightness: b);
}

final readingSettingsProvider = NotifierProvider<ReadingSettingsNotifier, ReadingSettings>(() {
  return ReadingSettingsNotifier();
});