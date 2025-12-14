import 'package:flutter/material.dart';
import 'package:epub_view/epub_view.dart' as epub_view;

class EpubReaderView extends StatefulWidget {
  final epub_view.EpubController controller; // [修改] 由外部传入
  final VoidCallback onToggleMenu;
  final Function(epub_view.EpubBook?)? onDocumentLoaded;
  final Function(String)? onPositionChanged;

  const EpubReaderView({
    super.key,
    required this.controller, // [修改]
    required this.onToggleMenu,
    this.onDocumentLoaded,
    this.onPositionChanged,
  });

  @override
  State<EpubReaderView> createState() => _EpubReaderViewState();
}

class _EpubReaderViewState extends State<EpubReaderView> {
  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: GestureDetector(
        onTap: widget.onToggleMenu,
        child: epub_view.EpubView(
          controller: widget.controller,
          onDocumentLoaded: widget.onDocumentLoaded,
          onChapterChanged: (_) {
            final cfi = widget.controller.generateEpubCfi();
            if (cfi != null) widget.onPositionChanged?.call(cfi);
          },
        ),
      ),
    );
  }
}