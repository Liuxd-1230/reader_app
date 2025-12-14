import 'package:isar_community/isar.dart';

part 'book.g.dart';

enum BookFormat { txt, epub, pdf }

@collection
class Book {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  late String title;
  late String author;
  late String filePath;
  String? coverPath;

  @enumerated
  late BookFormat format;

  // 统计信息
  int totalChapters = 0;
  int totalLength = 0;

  // --- 阅读进度字段更新 ---

  double progress = 0.0; // 0.0 - 1.0 用于显示进度条

  // 原有的 int 字段保留给 TXT/PDF 页码
  int lastReadChapterIndex = 0;
  int lastReadPosition = 0;

  // [新增] 专门用于存储 EPUB CFI 字符串或通用的字符串位置
  String? lastReadPositionStr;

  @Index()
  String? category;

  @Index()
  DateTime lastReadTime = DateTime.now();
  DateTime importTime = DateTime.now();
}