import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class PdfReaderView extends StatefulWidget {
  final String filePath;
  final VoidCallback onToggleMenu; // 回调：通知父级切换菜单

  const PdfReaderView({
    super.key,
    required this.filePath,
    required this.onToggleMenu,
  });

  @override
  State<PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends State<PdfReaderView> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PDFView(
          filePath: widget.filePath,
          enableSwipe: true,
          swipeHorizontal: true, // 开启左右翻页，符合阅读习惯
          autoSpacing: true,
          pageFling: true,
          pageSnap: true,
          defaultPage: 0,
          fitPolicy: FitPolicy.BOTH,
          preventLinkNavigation: false,
          onRender: (pages) {
            setState(() {
              _totalPages = pages!;
              _isReady = true;
            });
          },
          onPageChanged: (int? page, int? total) {
            setState(() {
              _currentPage = page!;
            });
          },
          onError: (error) {
            debugPrint(error.toString());
          },
        ),
        // 这是一个透明的层，专门用来检测点击事件
        // 因为 PDFView 会吞掉手势，我们需要用一种hack方式或者简单的浮层
        // 这里我们简化处理：利用 Stack 的穿透特性或者添加一个透明按钮层
        // 注意：flutter_pdfview 的手势处理很强势，简单的 GestureDetector 可能无效。
        // 一个常见的 iOS 风格做法是：点击屏幕中间 1/3 区域呼出菜单
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true, // 让 PDF 能够接收滑动
            child: Container(color: Colors.transparent),
          ),
        ),
        // 中心点击区域 (用于呼出菜单)
        Center(
          child: GestureDetector(
            onTap: widget.onToggleMenu,
            behavior: HitTestBehavior.translucent,
            child: Container(
              width: 200,
              height: 200,
              color: Colors.transparent,
            ),
          ),
        ),
        // 页码指示器
        if (_isReady)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${_currentPage + 1} / $_totalPages",
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
