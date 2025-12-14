import 'dart:io';
import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/reading_settings.dart';

class EpubReaderView extends ConsumerStatefulWidget {
  final String filePath;
  final VoidCallback onToggleMenu;
  // 使用 dynamic 规避类型报错
  final Function(dynamic chapter)? onChapterChanged;

  const EpubReaderView({
    super.key,
    required this.filePath,
    required this.onToggleMenu,
    this.onChapterChanged,
  });

  @override
  ConsumerState<EpubReaderView> createState() => _EpubReaderViewState();
}

class _EpubReaderViewState extends ConsumerState<EpubReaderView> {
  late EpubController _epubController;

  @override
  void initState() {
    super.initState();
    _epubController = EpubController(
      document: EpubDocument.openFile(File(widget.filePath)),
    );
  }

  @override
  void dispose() {
    _epubController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readingSettingsProvider);
    final theme = settings.currentTheme;
    final bool isDarkMode = theme.bgColor.computeLuminance() < 0.5;

    // 定义两个滤镜矩阵
    // 1. 反色矩阵 (深色模式用)
    const invertMatrix = ColorFilter.matrix([
      -1,  0,  0, 0, 255,
      0, -1,  0, 0, 255,
      0,  0, -1, 0, 255,
      0,  0,  0, 1,   0,
    ]);

    // 2. 正常矩阵 (浅色模式用，不做任何改变)
    const identityMatrix = ColorFilter.matrix([
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ]);

    return Container(
      color: theme.bgColor,
      child: GestureDetector(
        onTap: widget.onToggleMenu,
        // 【核心修复】始终保留 ColorFiltered 结构，只切换 filter 参数
        // 这样 Flutter 就不会销毁并重建 EpubView，防止 Controller 报错
        child: ColorFiltered(
          colorFilter: isDarkMode ? invertMatrix : identityMatrix,
          child: EpubView(
            controller: _epubController,
            builders: EpubViewBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              chapterDividerBuilder: (_) => const Divider(),
              loaderBuilder: (_) => Center(
                  child: CircularProgressIndicator(color: theme.textColor)),
            ),
            onChapterChanged: (value) {
              if (widget.onChapterChanged != null) {
                widget.onChapterChanged!(value);
              }
            },
            shrinkWrap: false,
          ),
        ),
      ),
    );
  }
}