import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// 使用 epubx 代替 epub_parser，解决依赖冲突
import 'package:epubx/epubx.dart' as epubx;
import 'package:image/image.dart' as img; // 用于处理封面图片

// 引入项目文件
import '../data/models/book.dart';
import '../data/services/database_service.dart';
import '../widgets/frosted_glass_container.dart';
import 'reading_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Book> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  /// 从数据库加载书籍
  Future<void> _loadBooks() async {
    final isar = DatabaseService().isar;
    // 按导入时间倒序查询
    final books = await isar.books.where().sortByImportTimeDesc().findAll();

    if (mounted) {
      setState(() {
        _books = books;
        _isLoading = false;
      });
    }
  }

  /// 核心逻辑：导入书籍并解析元数据 (封面、作者等)
  Future<void> _importBook() async {
    try {
      // 1. 打开文件选择器
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'epub', 'pdf'],
      );

      if (result != null) {
        if (!mounted) return;
        // 显示全屏 Loading，防止用户重复点击
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator()),
        );

        final PlatformFile file = result.files.first;
        final String originalPath = file.path!;

        // 2. 准备路径
        final appDir = await getApplicationDocumentsDirectory();
        final booksDir = Directory('${appDir.path}/books');
        final coversDir = Directory('${appDir.path}/covers'); // 封面存储目录

        if (!await booksDir.exists()) await booksDir.create(recursive: true);
        if (!await coversDir.exists()) await coversDir.create(recursive: true);

        // 3. 复制书籍文件
        final String fileName = file.name;
        final String newPath = '${booksDir.path}/$fileName';
        final File localFile = await File(originalPath).copy(newPath);

        // 4. 初始化基本信息
        String title = p.basenameWithoutExtension(fileName);
        String author = "本地导入"; // 默认作者
        String? coverPath;      // 默认无封面
        BookFormat format;

        final ext = p.extension(fileName).toLowerCase().replaceAll('.', '');

        // 5. 格式判断与解析
        if (ext == 'epub') {
          format = BookFormat.epub;
          try {
            // 读取文件字节
            List<int> bytes = await localFile.readAsBytes();

            // 使用 epubx 解析 (它和 epub_view 兼容)
            epubx.EpubBook epubBook = await epubx.EpubReader.readBook(bytes);

            // 提取元数据
            title = epubBook.Title ?? title;
            author = epubBook.Author ?? author;

            // 提取封面
            // epubx v4.0+ 的 CoverImage 直接返回 image 库的 Image 对象
            img.Image? coverImage = epubBook.CoverImage;

            if (coverImage != null) {
              // 生成唯一的封面文件名
              final coverName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
              final coverFile = File('${coversDir.path}/$coverName');

              // 将图片编码为 JPG 并保存
              await coverFile.writeAsBytes(img.encodeJpg(coverImage));
              coverPath = coverFile.path;
            }
          } catch (e) {
            debugPrint("EPUB 解析警告: $e (不影响导入，仅缺失元数据)");
          }
        } else if (ext == 'pdf') {
          format = BookFormat.pdf;
          // PDF 封面提取通常需要更复杂的原生库 (如 pdf_renderer)，这里暂留空
        } else {
          format = BookFormat.txt;
        }

        // 6. 存入数据库
        final newBook = Book()
          ..title = title
          ..author = author
          ..filePath = newPath
          ..coverPath = coverPath // 如果解析成功，这里会有路径
          ..format = format
          ..importTime = DateTime.now()
          ..progress = 0.0;

        final isar = DatabaseService().isar;
        await isar.writeTxn(() async {
          await isar.books.put(newBook);
        });

        // 7. 完成
        if(mounted) Navigator.pop(context); // 关闭 Loading
        await _loadBooks(); // 刷新列表

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入成功！')),
        );
      }
    } catch (e) {
      if(mounted && Navigator.canPop(context)) Navigator.pop(context); // 确保关闭 Loading
      debugPrint('Import Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

  /// 获取对应格式的默认图标 (当没有封面时显示)
  IconData _getIconForFormat(BookFormat format) {
    switch (format) {
      case BookFormat.pdf:
        return Icons.picture_as_pdf;
      case BookFormat.epub:
        return Icons.local_library;
      case BookFormat.txt:
      default:
        return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Layer 1: 背景壁纸 (弥散渐变)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFE2D1), // 粉橘
                    Color(0xFFE1F5FE), // 淡蓝
                    Color(0xFFE8F5E9), // 淡绿
                  ],
                ),
              ),
            ),
          ),

          // Layer 2: 书籍列表
          _buildBookGrid(),

          // Layer 3: 顶部毛玻璃 AppBar
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildFrostedAppBar(),
          ),

          // Layer 4: 底部毛玻璃 FAB
          Positioned(
            bottom: 30, right: 20,
            child: _buildFrostedFAB(),
          ),
        ],
      ),
    );
  }

  // --- UI 构建方法 ---

  Widget _buildBookGrid() {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final topPadding = statusBarHeight + 100;

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _books.isEmpty
          ? _buildEmptyState()
          : GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65, // 封面比例
          crossAxisSpacing: 15,
          mainAxisSpacing: 25,
        ),
        itemCount: _books.length,
        itemBuilder: (context, index) {
          return _buildBookItem(_books[index]);
        },
      ),
    );
  }

  Widget _buildBookItem(Book book) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReadingScreen(book: book),
          ),
        );
      },
      child: Column(
        children: [
          Expanded(
            child: FrostedGlassContainer(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(8),
              // 如果有封面路径，优先显示图片
              child: book.coverPath != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(book.coverPath!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  // 如果图片加载失败，回退到默认图标
                  errorBuilder: (context, error, stackTrace) {
                    return _buildDefaultCover(book);
                  },
                ),
              )
                  : _buildDefaultCover(book),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // 默认封面 (无图片时显示)
  Widget _buildDefaultCover(Book book) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIconForFormat(book.format),
            size: 40,
            color: Colors.black54,
          ),
          // 非 EPUB 显示格式文字
          if (book.format != BookFormat.epub)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                book.format.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black45,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FrostedGlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.library_books_outlined, size: 48, color: Colors.black54),
            SizedBox(height: 16),
            Text(
              "书架空空如也",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 8),
            Text(
              "点击右下角按钮导入书籍\n支持 TXT, EPUB, PDF",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrostedAppBar() {
    return ClipRRect(
      child: FrostedGlassContainer(
        height: null,
        borderRadius: BorderRadius.zero,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 15,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "我的书架",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: 0.5,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search, size: 28, color: Colors.black87),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrostedFAB() {
    return GestureDetector(
      onTap: _importBook,
      child: FrostedGlassContainer(
        width: 60,
        height: 60,
        borderRadius: BorderRadius.circular(30),
        padding: EdgeInsets.zero,
        child: const Center(
          child: Icon(Icons.add, size: 30, color: Colors.black87),
        ),
      ),
    );
  }
}