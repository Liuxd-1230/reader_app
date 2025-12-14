import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfReaderView extends StatefulWidget {
  final String filePath;
  final int initialPage;
  final VoidCallback onToggleMenu;
  final Function(int page, int total)? onPageChanged;
  final Function(PDFViewController)? onControllerCreated; // [新增] 回传 Controller

  const PdfReaderView({
    super.key,
    required this.filePath,
    this.initialPage = 0,
    required this.onToggleMenu,
    this.onPageChanged,
    this.onControllerCreated,
  });

  @override
  State<PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends State<PdfReaderView> {
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PDFView(
          filePath: widget.filePath,
          defaultPage: widget.initialPage,
          onViewCreated: (controller) {
            widget.onControllerCreated?.call(controller); // 回传
          },
          onRender: (pages) => setState(() => _totalPages = pages ?? 0),
          onPageChanged: (page, total) {
            setState(() => _currentPage = page ?? 0);
            widget.onPageChanged?.call(page ?? 0, total ?? 0);
          },
        ),
        // ... (保持原来的点击层和页码显示逻辑)
        Center(
          child: GestureDetector(
            onTap: widget.onToggleMenu,
            behavior: HitTestBehavior.translucent,
            child: Container(width: 200, height: 200, color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}