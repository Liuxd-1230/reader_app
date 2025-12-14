import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:epub_view/epub_view.dart' as epub_view;
import 'package:flutter_pdfview/flutter_pdfview.dart';

import '../data/models/book.dart';
import '../data/models/bookmark.dart';
import '../data/models/reading_settings.dart';
import '../data/services/database_service.dart';
import '../widgets/frosted_glass_container.dart';
import '../widgets/readers/pdf_reader_view.dart';
import '../widgets/readers/epub_reader_view.dart';
import '../utils/deepseek_selection_controls.dart';

class ReadingScreen extends ConsumerStatefulWidget {
  final Book book;
  const ReadingScreen({super.key, required this.book});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> with SingleTickerProviderStateMixin {
  bool _showMenu = false;

  epub_view.EpubController? _epubController;
  PDFViewController? _pdfController;
  final PageController _txtPageController = PageController();

  epub_view.EpubBook? _loadedBook;
  List<epub_view.EpubChapter>? _epubTOC;
  List<String> _txtPages = [];
  bool _isTxtLoading = false;

  int _currentTxtPageIndex = 0;
  int _totalPdfPages = 0;
  int _currentPdfPage = 0;

  late final DeepSeekSelectionControls _selectionControls;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _selectionControls = DeepSeekSelectionControls(onDeepSeekExplain: _handleAiExplain);

    if (widget.book.format == BookFormat.epub) {
      _epubController = epub_view.EpubController(
        document: epub_view.EpubDocument.openFile(File(widget.book.filePath)),
        epubCfi: widget.book.lastReadPositionStr,
      );
    } else if (widget.book.format == BookFormat.txt) {
      _loadTxtContent();
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _epubController?.dispose();
    _txtPageController.dispose();
    super.dispose();
  }

  Future<void> _loadTxtContent() async {
    setState(() => _isTxtLoading = true);
    try {
      final file = File(widget.book.filePath);
      if (!await file.exists()) throw Exception("文件不存在");
      final content = await file.readAsString();
      List<String> pages = [];
      const int pageSize = 500;
      for(int i=0; i<content.length; i+=pageSize) {
        int end = (i + pageSize < content.length) ? i + pageSize : content.length;
        pages.add(content.substring(i, end));
      }
      if (pages.isEmpty) pages.add("无内容");

      if (mounted) {
        setState(() { _txtPages = pages; _isTxtLoading = false; });
        if (widget.book.lastReadPosition > 0 && widget.book.lastReadPosition < pages.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if(_txtPageController.hasClients) _txtPageController.jumpToPage(widget.book.lastReadPosition);
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _txtPages = ["加载出错: $e"]; _isTxtLoading = false; });
    }
  }

  void _toggleMenu() {
    setState(() => _showMenu = !_showMenu);
    if (_showMenu) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _handleAiExplain(String text) async {
    final settings = ref.read(readingSettingsProvider);
    final theme = settings.currentTheme;
    final isDark = theme.bgColor.computeLuminance() < 0.5;

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final result = await fetchDeepSeekExplanation(text, settings.deepSeekApiKey ?? "");
    if(mounted) Navigator.pop(context);

    if(mounted) {
      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => FrostedGlassContainer(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              padding: const EdgeInsets.all(24),
              // [UI优化] 深色模式使用深灰底色，不透明度0.9，保证文字清晰
              glassColor: isDark ? const Color(0xFF1D1D1D) : Colors.white,
              opacity: 0.9,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: isDark ? Colors.white : Colors.black87),
                        const SizedBox(width: 8),
                        Text("AI 解读", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                    Divider(color: isDark ? Colors.white24 : Colors.black12),
                    Text(result, style: TextStyle(fontSize: 16, height: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
                    const SizedBox(height: 20),
                  ],
                ),
              )
          )
      );
    }
  }

  Future<void> _saveProgress({String? positionStr, int? index, double? progress}) async {
    final isar = DatabaseService().isar;
    await isar.writeTxn(() async {
      final b = await isar.books.get(widget.book.id);
      if (b != null) {
        if (positionStr != null) b.lastReadPositionStr = positionStr;
        if (index != null) b.lastReadPosition = index;
        if (progress != null) b.progress = progress;
        b.lastReadTime = DateTime.now();
        await isar.books.put(b);
      }
    });
  }

  Future<void> _addBookmark() async {
    final isar = DatabaseService().isar;
    final newBookmark = Bookmark()..bookId = widget.book.id..timestamp = DateTime.now();
    if (widget.book.format == BookFormat.txt && _txtPages.isNotEmpty) {
      newBookmark.chapterIndex = _currentTxtPageIndex;
      String p = _txtPages[_currentTxtPageIndex];
      newBookmark.previewText = p.length > 20 ? "${p.substring(0, 20)}..." : p;
    } else {
      newBookmark.previewText = "书签 (${DateTime.now().toString().substring(5, 16)})";
    }
    await isar.writeTxn(() async => await isar.bookmarks.put(newBookmark));
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("书签已保存")));
  }

  bool _isDarkMode(ReaderTheme theme) {
    return theme.bgColor.computeLuminance() < 0.5;
  }

  // [关键] 辅助函数：清洗 URL (去除 #hash)
  String _cleanHref(String? href) {
    if (href == null) return "";
    return href.split('#').first;
  }

  // [关键] 修复跳转：通过清洗后的 Href 匹配 Spine
  int? _getSpineIndexFromChapter(epub_view.EpubChapter chapter) {
    final doc = _loadedBook;
    if (doc == null || chapter.ContentFileName == null) return null;

    final spineItems = doc.Schema?.Package?.Spine?.Items;
    final manifestItems = doc.Schema?.Package?.Manifest?.Items;

    if (spineItems == null || manifestItems == null) return null;

    final targetHref = _cleanHref(chapter.ContentFileName);

    for (int i = 0; i < spineItems.length; i++) {
      final spineId = spineItems[i].IdRef;
      final manifestItem = manifestItems.firstWhere(
              (m) => m.Id == spineId,
          orElse: () => epub_view.EpubManifestItem()
      );

      // 对比清洗后的路径
      if (_cleanHref(manifestItem.Href) == targetHref) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readingSettingsProvider);
    final theme = settings.currentTheme;
    final isDark = _isDarkMode(theme);

    return Scaffold(
      backgroundColor: theme.bgColor,
      body: Stack(
        children: [
          // 1. 阅读层
          Positioned.fill(child: _buildReaderBody(settings, theme)),

          // 2. 亮度遮罩
          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: Colors.black.withOpacity(1.0 - settings.brightness)),
            ),
          ),

          // 3. 顶部菜单
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutQuart,
            top: _showMenu ? 0 : -100,
            left: 0, right: 0,
            child: _buildTopBar(theme),
          ),

          // 4. 底部菜单
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutQuart,
            bottom: _showMenu ? 0 : -220,
            left: 0, right: 0,
            child: _buildBottomBar(context, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderBody(ReadingSettings settings, ReaderTheme theme) {
    if (_isTxtLoading) return Center(child: CircularProgressIndicator(color: theme.textColor));
    final isDark = _isDarkMode(theme);

    switch (widget.book.format) {
      case BookFormat.pdf:
        return PdfReaderView(
          filePath: widget.book.filePath,
          initialPage: widget.book.lastReadPosition,
          onToggleMenu: _toggleMenu,
          onControllerCreated: (c) => _pdfController = c,
          onPageChanged: (page, total) {
            _currentPdfPage = page;
            _totalPdfPages = total;
            _saveProgress(index: page, progress: page/total);
          },
        );
      case BookFormat.epub:
      // 深色模式反转
        return ColorFiltered(
          colorFilter: isDark
              ? const ColorFilter.matrix([
            -1,  0,  0, 0, 255,
            0, -1,  0, 0, 255,
            0,  0, -1, 0, 255,
            0,  0,  0, 1,   0,
          ])
              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: EpubReaderView(
            controller: _epubController!,
            onToggleMenu: _toggleMenu,
            onDocumentLoaded: (doc) {
              setState(() {
                _loadedBook = doc;
                _epubTOC = doc?.Chapters;
              });
            },
            onPositionChanged: (cfi) => _saveProgress(positionStr: cfi),
          ),
        );
      default:
        return GestureDetector(
          onTap: _toggleMenu,
          child: PageView.builder(
            controller: _txtPageController,
            itemCount: _txtPages.length,
            onPageChanged: (idx) {
              _currentTxtPageIndex = idx;
              _saveProgress(index: idx, progress: idx/_txtPages.length);
            },
            itemBuilder: (context, index) => Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 20),
              child: SelectableText(
                _txtPages[index],
                style: TextStyle(fontSize: settings.fontSize, color: theme.textColor, height: 1.6),
                selectionControls: _selectionControls,
                onTap: _toggleMenu,
              ),
            ),
          ),
        );
    }
  }

  Widget _buildTopBar(ReaderTheme theme) {
    final isDark = _isDarkMode(theme);
    // 定义深色模式下的毛玻璃颜色 (深灰)
    final glassColor = isDark ? const Color(0xFF1D1D1D) : Colors.white;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: FrostedGlassContainer(
          height: 60,
          borderRadius: BorderRadius.circular(30),
          glassColor: glassColor,
          opacity: 0.8, // 统一透光度
          blur: 25,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new, size: 20, color: theme.textColor),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  widget.book.title,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.textColor),
                ),
              ),
              IconButton(
                icon: Icon(Icons.bookmark_border, color: theme.textColor),
                onPressed: _addBookmark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ReaderTheme theme) {
    final isDark = _isDarkMode(theme);
    final glassColor = isDark ? const Color(0xFF1D1D1D) : Colors.white;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FrostedGlassContainer(
          borderRadius: BorderRadius.circular(24),
          glassColor: glassColor,
          opacity: 0.8, // 与顶部保持一致
          blur: 25,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.book.format != BookFormat.epub)
                Row(
                  children: [
                    Text("进度", style: TextStyle(fontSize: 10, color: theme.textColor)),
                    Expanded(
                      child: Slider(
                        value: _getProgressValue(),
                        onChanged: (v) {
                          if(widget.book.format == BookFormat.txt) {
                            _txtPageController.jumpToPage((v * _txtPages.length).round());
                          } else if (widget.book.format == BookFormat.pdf) {
                            _pdfController?.setPage((v * _totalPdfPages).round());
                          }
                        },
                        activeColor: theme.textColor,
                        inactiveColor: theme.textColor.withOpacity(0.3),
                        thumbColor: theme.textColor,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _iconBtn(Icons.format_list_bulleted, "目录", theme, () => _showIOCatalog(context, isDark)),
                  _iconBtn(Icons.wb_sunny_outlined, "外观", theme, () => _showSettings(context, isDark)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getProgressValue() {
    if (widget.book.format == BookFormat.txt && _txtPages.isNotEmpty) return _currentTxtPageIndex / _txtPages.length;
    if (widget.book.format == BookFormat.pdf && _totalPdfPages > 0) return _currentPdfPage / _totalPdfPages;
    return 0.0;
  }

  Widget _iconBtn(IconData icon, String label, ReaderTheme theme, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Column(
        children: [
          Icon(icon, color: theme.textColor),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: theme.textColor)),
        ],
      ),
    );
  }

  void _showIOCatalog(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _IOSCatalogSheet(
          book: widget.book,
          epubTOC: _epubTOC,
          isDark: isDark,
          onJump: (chapter) {
            Navigator.pop(context);
            if(widget.book.format == BookFormat.epub) {
              if (chapter is epub_view.EpubChapter) {
                final realIndex = _getSpineIndexFromChapter(chapter);
                if (realIndex != null) {
                  _epubController?.scrollTo(index: realIndex, duration: const Duration(milliseconds: 300));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("无法定位该章节")));
                }
              }
            } else if (widget.book.format == BookFormat.txt) {
              _txtPageController.jumpToPage(chapter as int);
            }
          }
      ),
    );
  }

  void _showSettings(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(builder: (context, ref, _) {
        final settings = ref.watch(readingSettingsProvider);
        return FrostedGlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          glassColor: isDark ? const Color(0xFF1D1D1D) : Colors.white,
          opacity: 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("亮度", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              Slider(
                value: settings.brightness, min: 0.2, max: 1.0,
                activeColor: isDark ? Colors.white : Colors.black,
                onChanged: (v) => ref.read(readingSettingsProvider.notifier).setBrightness(v),
              ),
              Text("字号", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              Slider(
                value: settings.fontSize, min: 12, max: 32, divisions: 10,
                activeColor: isDark ? Colors.white : Colors.black,
                onChanged: (v) => ref.read(readingSettingsProvider.notifier).setFontSize(v),
              ),
              Text("主题", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(themes.length, (i) => GestureDetector(
                    onTap: () => ref.read(readingSettingsProvider.notifier).setTheme(i),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: themes[i].bgColor, shape: BoxShape.circle, border: Border.all(color: Colors.grey)),
                      child: settings.themeIndex == i ? Icon(Icons.check, size: 20, color: i == 3 ? Colors.white : Colors.black) : null,
                    ),
                  )),
                ),
              )
            ],
          ),
        );
      }),
    );
  }
}

class _IOSCatalogSheet extends StatelessWidget {
  final Book book;
  final List<epub_view.EpubChapter>? epubTOC;
  final Function(dynamic) onJump;
  final bool isDark;

  const _IOSCatalogSheet({required this.book, this.epubTOC, required this.onJump, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // [UI优化] 目录页也使用深灰底色+0.8不透明度，透光感更好
    return FrostedGlassContainer(
      height: MediaQuery.of(context).size.height * 0.7,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      glassColor: isDark ? const Color(0xFF1D1D1D) : Colors.white,
      opacity: 0.8,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Expanded(
            child: epubTOC == null
                ? Center(child: Text("无目录", style: TextStyle(color: isDark ? Colors.white : Colors.black)))
                : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: epubTOC!.length,
              separatorBuilder: (_,__) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
              itemBuilder: (c, i) => ListTile(
                title: Text(
                  epubTOC![i].Title?.trim() ?? "章节 $i",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
                ),
                trailing: Icon(Icons.chevron_right, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                onTap: () => onJump(epubTOC![i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}