import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:epubx/epubx.dart' as epubx;
import 'package:image/image.dart' as img;

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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final isar = DatabaseService().isar;
    final books = await isar.books.where().sortByImportTimeDesc().findAll();
    if (mounted) setState(() { _books = books; _isLoading = false; });
  }

  Future<void> _deleteBook(Book book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: FrostedGlassContainer(
          borderRadius: BorderRadius.circular(20),
          width: 300,
          opacity: 0.95,
          glassColor: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("删除书籍", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text("确定要移除《${book.title}》吗？", textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("删除", style: TextStyle(color: Colors.red)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      final isar = DatabaseService().isar;
      await isar.writeTxn(() async {
        await isar.books.delete(book.id);
      });
      _loadBooks();
    }
  }

  Future<void> _importBook() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'epub', 'pdf'],
      );

      if (result != null) {
        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black12,
          builder: (c) => Center(
            child: FrostedGlassContainer(
              width: 140, height: 140,
              borderRadius: BorderRadius.circular(24),
              blur: 20,
              opacity: 0.7,
              glassColor: Colors.white,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3, color: Colors.black87),
                  SizedBox(height: 16),
                  Text("导入中...", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))
                ],
              ),
            ),
          ),
        );

        final PlatformFile file = result.files.first;
        final appDir = await getApplicationDocumentsDirectory();
        final booksDir = Directory('${appDir.path}/books');
        final coversDir = Directory('${appDir.path}/covers');
        if (!await booksDir.exists()) await booksDir.create(recursive: true);
        if (!await coversDir.exists()) await coversDir.create(recursive: true);

        final String newPath = '${booksDir.path}/${file.name}';
        await File(file.path!).copy(newPath);

        String title = p.basenameWithoutExtension(file.name);
        String? coverPath;
        BookFormat format = BookFormat.txt;
        final ext = p.extension(file.name).toLowerCase();

        if (ext == '.epub') {
          format = BookFormat.epub;
          try {
            final bytes = await File(newPath).readAsBytes();
            final epubBook = await epubx.EpubReader.readBook(bytes);
            title = epubBook.Title ?? title;
            final img.Image? coverImage = epubBook.CoverImage;
            if (coverImage != null) {
              final coverName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
              final coverFile = File('${coversDir.path}/$coverName');
              await coverFile.writeAsBytes(img.encodeJpg(coverImage));
              coverPath = coverFile.path;
            }
          } catch (_) {}
        } else if (ext == '.pdf') {
          format = BookFormat.pdf;
        }

        final newBook = Book()
          ..title = title
          ..author = "本地导入"
          ..filePath = newPath
          ..coverPath = coverPath
          ..format = format
          ..importTime = DateTime.now();

        final isar = DatabaseService().isar;
        await isar.writeTxn(() async => await isar.books.put(newBook));

        if(mounted) Navigator.pop(context);
        _loadBooks();
      }
    } catch (e) {
      if(mounted && Navigator.canPop(context)) Navigator.pop(context);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("导入失败: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF5F7FA), Color(0xFFC3CFE2)],
                ),
              ),
            ),
          ),

          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 120.0,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                  title: Text(
                    '我的书架',
                    style: TextStyle(
                      color: Colors.black87.withOpacity(0.8),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // [修改] 移除了 actions (搜索按钮)
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                sliver: _isLoading
                    ? const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))
                    : _books.isEmpty
                    ? SliverToBoxAdapter(child: _buildEmptyState())
                    : SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 24,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final book = _books[index];
                      return _BookItem(
                        book: book,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (c) => ReadingScreen(book: book)),
                          );
                          _loadBooks();
                        },
                        onLongPress: () => _deleteBook(book),
                      );
                    },
                    childCount: _books.length,
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            bottom: 40, right: 24,
            child: GestureDetector(
              onTap: () { HapticFeedback.mediumImpact(); _importBook(); },
              child: FrostedGlassContainer(
                width: 60, height: 60,
                borderRadius: BorderRadius.circular(30),
                padding: EdgeInsets.zero,
                glassColor: Colors.black,
                opacity: 0.8,
                child: const Center(child: Icon(Icons.add, size: 32, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.import_contacts, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text("书架空空如也", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
      ],
    );
  }
}

class _BookItem extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookItem({required this.book, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () { HapticFeedback.heavyImpact(); onLongPress(); },
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(3, 6))
                ],
                image: book.coverPath != null
                    ? DecorationImage(image: FileImage(File(book.coverPath!)), fit: BoxFit.cover)
                    : null,
                color: Colors.white,
              ),
              child: book.coverPath == null
                  ? Center(child: Icon(Icons.book, size: 36, color: Colors.grey[300]))
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}