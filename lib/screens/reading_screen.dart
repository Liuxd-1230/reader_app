import 'dart:io';
import 'package:epub_view/epub_view.dart' as epub;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

// Models & Services
import '../data/models/book.dart';
import '../data/models/bookmark.dart';
import '../data/models/reading_settings.dart';
import '../data/services/database_service.dart';

// Widgets & Utils
import '../widgets/frosted_glass_container.dart';
import '../widgets/readers/pdf_reader_view.dart';
import '../widgets/readers/epub_reader_view.dart';
import '../utils/deepseek_selection_controls.dart'; // 👈 引入新文件

class ReadingScreen extends ConsumerStatefulWidget {
  final Book book;
  const ReadingScreen({super.key, required this.book});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> with SingleTickerProviderStateMixin {
  // UI 状态
  bool _showMenu = false;
  late TabController _drawerTabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // 数据状态
  List<Bookmark> _bookmarks = [];

  // TXT 专用
  bool _isTxtLoading = true;
  List<String> _txtPages = [];
  final PageController _txtPageController = PageController();
  int _currentTxtPageIndex = 0;

  // 🔴 缓存我们的自定义控制器，避免频繁重建
  late final DeepSeekSelectionControls _selectionControls;

  @override
  void initState() {
    super.initState();
    _drawerTabController = TabController(length: 2, vsync: this);
    _loadBookmarks();

    // 初始化自定义选择控制器
    _selectionControls = DeepSeekSelectionControls(
      onDeepSeekExplain: (selectedText) {
        // ✨ 这里是 AI 逻辑的入口
        debugPrint("🤖 DeepSeek Triggered: $selectedText");

        // 暂时先弹个窗显示选中的内容，证明我们捕获到了
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("DeepSeek 思考中..."),
            content: Text("你选中了：\n\n$selectedText"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("关闭"))
            ],
          ),
        );
      },
    );

    if (widget.book.format == BookFormat.txt) {
      _loadTxtContent();
    }
  }

  @override
  void dispose() {
    _txtPageController.dispose();
    _drawerTabController.dispose();
    super.dispose();
  }

  void _toggleMenu() => setState(() => _showMenu = !_showMenu);

  Future<void> _loadBookmarks() async {
    final isar = DatabaseService().isar;
    final bookmarks = await isar.bookmarks
        .filter()
        .bookIdEqualTo(widget.book.id)
        .sortByTimestampDesc()
        .findAll();
    if (mounted) setState(() => _bookmarks = bookmarks);
  }

  Future<void> _addBookmark() async {
    final isar = DatabaseService().isar;
    final newBookmark = Bookmark()
      ..bookId = widget.book.id
      ..timestamp = DateTime.now();

    if (widget.book.format == BookFormat.txt) {
      newBookmark.chapterIndex = _currentTxtPageIndex;
      String preview = _txtPages[_currentTxtPageIndex];
      newBookmark.previewText = preview.length > 50 ? preview.substring(0, 50) : preview;
    } else if (widget.book.format == BookFormat.epub) {
      newBookmark.chapterIndex = 0;
      newBookmark.previewText = "EPUB 进度 (自动保存)";
    } else {
      newBookmark.previewText = "PDF 书签";
    }

    await isar.writeTxn(() async {
      await isar.bookmarks.put(newBookmark);
    });

    await _loadBookmarks();
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("书签已添加")));
    }
  }

  Future<void> _loadTxtContent() async {
    try {
      final file = File(widget.book.filePath);
      if (!await file.exists()) {
        if (mounted) setState(() => _txtPages = ["文件不存在"]);
        return;
      }
      final content = await file.readAsString();
      final RegExp chapterRegex = RegExp(r"(第\s*[0-9零一二三四五六七八九十百千]+\s*章)");
      final matches = chapterRegex.allMatches(content).toList();
      List<String> chunks = [];
      if (matches.isNotEmpty) {
        int lastIndex = 0;
        for (var match in matches) {
          if (match.start > lastIndex) chunks.add(content.substring(lastIndex, match.start));
          lastIndex = match.start;
        }
        if (lastIndex < content.length) chunks.add(content.substring(lastIndex));
      } else {
        const int chunkSize = 3000;
        for (int i = 0; i < content.length; i += chunkSize) {
          int end = (i + chunkSize < content.length) ? i + chunkSize : content.length;
          chunks.add(content.substring(i, end));
        }
      }
      chunks = chunks.where((s) => s.trim().isNotEmpty).toList();
      if (chunks.isEmpty) chunks.add("内容为空");
      if (mounted) setState(() { _txtPages = chunks; _isTxtLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _txtPages = ["读取出错: $e"]; _isTxtLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readingSettingsProvider);
    final theme = settings.currentTheme;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.bgColor,
      extendBodyBehindAppBar: true,
      endDrawer: _buildDrawer(),
      body: Stack(
        children: [
          Positioned.fill(child: _buildReaderBody(settings, theme)),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showMenu ? 0 : -120,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showMenu ? 0 : -160,
            left: 0,
            right: 0,
            child: _buildBottomBar(settings),
          ),
        ],
      ),
    );
  }

  Widget _buildReaderBody(ReadingSettings settings, ReaderTheme theme) {
    switch (widget.book.format) {
      case BookFormat.pdf:
        return PdfReaderView(
          filePath: widget.book.filePath,
          onToggleMenu: _toggleMenu,
        );
      case BookFormat.epub:
        return EpubReaderView(
          filePath: widget.book.filePath,
          onToggleMenu: _toggleMenu,
          onChapterChanged: (value) {},
        );
      case BookFormat.txt:
      default:
        if (_isTxtLoading) return const Center(child: CircularProgressIndicator());

        // 🔴 核心修改：使用 PageView 包裹 SelectableText
        return GestureDetector(
          onTap: _toggleMenu,
          child: PageView.builder(
            controller: _txtPageController,
            itemCount: _txtPages.length,
            onPageChanged: (index) {
              _currentTxtPageIndex = index;
            },
            itemBuilder: (context, index) {
              return Container(
                color: Colors.transparent,
                padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    left: 20, right: 20, bottom: 40
                ),
                // ✨ 将 Text 替换为 SelectableText
                child: SelectableText(
                  _txtPages[index],
                  style: TextStyle(
                    fontSize: settings.fontSize,
                    color: theme.textColor,
                    height: 1.8,
                  ),
                  // ✨ 绑定我们的自定义控制器
                  selectionControls: _selectionControls,
                  // 允许点击事件穿透到上层的 GestureDetector (用于呼出菜单)
                  onTap: () {
                    _toggleMenu();
                  },
                ),
              );
            },
          ),
        );
    }
  }

  // --- UI Components ---
  // (保持不变，省略以节省篇幅，请直接保留你上一次的 UI 代码)
  // 如果你需要我再次提供完整的 UI 代码，请告诉我，但上面的修改只涉及 _buildReaderBody
  // ...

  Widget _buildTopBar() {
    return FrostedGlassContainer(
      height: null,
      borderRadius: BorderRadius.zero,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 10, right: 10, bottom: 15
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(widget.book.title, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined, color: Colors.black87),
            onPressed: _addBookmark,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.85,
      child: FrostedGlassContainer(
        borderRadius: BorderRadius.zero,
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20),
        child: Column(
          children: [
            TabBar(
              controller: _drawerTabController,
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.black45,
              indicatorColor: Colors.black87,
              tabs: const [Tab(text: "目录"), Tab(text: "书签")],
            ),
            Expanded(
              child: TabBarView(
                controller: _drawerTabController,
                children: [_buildTOCList(), _buildBookmarkList()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTOCList() {
    if (widget.book.format == BookFormat.txt) {
      return ListView.builder(
        itemCount: _txtPages.length,
        itemBuilder: (context, index) {
          String preview = _txtPages[index].trim().split('\n').first;
          if (preview.length > 20) preview = "${preview.substring(0, 20)}...";
          return ListTile(
            title: Text(preview, style: const TextStyle(fontSize: 14)),
            subtitle: Text("第 ${index + 1} 页"),
            onTap: () { _txtPageController.jumpToPage(index); Navigator.pop(context); },
          );
        },
      );
    }
    return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("EPUB/PDF 目录功能暂未接入")));
  }

  Widget _buildBookmarkList() {
    if (_bookmarks.isEmpty) return const Center(child: Text("暂无书签", style: TextStyle(color: Colors.grey)));
    return ListView.separated(
      itemCount: _bookmarks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final bookmark = _bookmarks[index];
        return ListTile(
          leading: const Icon(Icons.bookmark, color: Colors.amber),
          title: Text(bookmark.previewText, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text("添加于: ${bookmark.timestamp.toString().substring(0, 16)}"),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () async {
              final isar = DatabaseService().isar;
              await isar.writeTxn(() async { await isar.bookmarks.delete(bookmark.id); });
              _loadBookmarks();
            },
          ),
          onTap: () {
            if (widget.book.format == BookFormat.txt) { _txtPageController.jumpToPage(bookmark.chapterIndex); }
            Navigator.pop(context);
          },
        );
      },
    );
  }

  Widget _buildBottomBar(ReadingSettings settings) {
    return FrostedGlassContainer(
      borderRadius: BorderRadius.zero,
      padding: EdgeInsets.only(top: 20, bottom: MediaQuery.of(context).padding.bottom + 20, left: 20, right: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          InkWell(
            onTap: () { _toggleMenu(); _scaffoldKey.currentState?.openEndDrawer(); },
            child: Column(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.format_list_bulleted, size: 26, color: Colors.black87), SizedBox(height: 4), Text("目录/书签", style: TextStyle(fontSize: 10, color: Colors.black87))]),
          ),
          InkWell(
            onTap: widget.book.format == BookFormat.pdf ? null : () => _showSettingsSheet(context),
            child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.text_fields, size: 26, color: widget.book.format == BookFormat.pdf ? Colors.grey : Colors.black87), const SizedBox(height: 4), Text("设置", style: TextStyle(fontSize: 10, color: widget.book.format == BookFormat.pdf ? Colors.grey : Colors.black87))]),
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(builder: (context, ref, _) {
          final settings = ref.watch(readingSettingsProvider);
          return FrostedGlassContainer(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            padding: const EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.format_size, size: 20), const SizedBox(width: 10), const Text("字号", style: TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text("${settings.fontSize.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold))]),
              Slider(value: settings.fontSize, min: 12, max: 32, divisions: 10, activeColor: Colors.black87, inactiveColor: Colors.black12, onChanged: (val) { ref.read(readingSettingsProvider.notifier).setFontSize(val); }),
              const SizedBox(height: 20),
              const Text("阅读背景", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(themes.length, (index) {
                final theme = themes[index];
                final isSelected = settings.themeIndex == index;
                return GestureDetector(onTap: () { ref.read(readingSettingsProvider.notifier).setTheme(index); }, child: Container(width: 45, height: 45, decoration: BoxDecoration(color: theme.bgColor, shape: BoxShape.circle, border: Border.all(color: isSelected ? Colors.blueAccent : Colors.grey.shade300, width: isSelected ? 2.5 : 1), boxShadow: [if (isSelected) BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]), child: isSelected ? const Icon(Icons.check, size: 20, color: Colors.blueAccent) : null));
              })),
              const SizedBox(height: 20),
            ]),
          );
        });
      },
    );
  }
}