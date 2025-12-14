import 'package:isar_community/isar.dart';

// 生成的文件名必须与当前文件名一致
part 'book.g.dart';

enum BookFormat {
  txt,
  epub,
  pdf,
}

@collection
class Book {
  // 1. ID: 自增主键
  Id id = Isar.autoIncrement;

  // 2. 元数据
  @Index(type: IndexType.value) // 允许按标题搜索
  late String title;

  late String author;

  // 3. 文件路径 (本地存储位置)
  late String filePath;

  // 4. 封面图片路径 (可选)
  String? coverPath;

  // 5. 格式类型 (使用枚举)
  @enumerated
  late BookFormat format;

  // 6. 统计信息
  int totalChapters = 0; // 总章节数
  int totalLength = 0;   // 总字符数/文件大小

  // 7. 阅读进度
  double progress = 0.0; // 0.0 - 1.0 用于进度条
  int lastReadChapterIndex = 0; // 当前章节索引
  int lastReadPosition = 0;     // 当前章节内的字符位置/滚动位置

  // 8. 分类/文件夹 (可选)
  @Index()
  String? category;

  // 时间戳
  @Index()
  DateTime lastReadTime = DateTime.now();

  DateTime importTime = DateTime.now();
}