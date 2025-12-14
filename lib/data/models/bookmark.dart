import 'package:isar_community/isar.dart';

part 'bookmark.g.dart';

@collection
class Bookmark {
  // 通常 v4 依然兼容 Isar.autoIncrement。
// 如果编辑器报错，请改成：

  Id id = Isar.autoIncrement;

  // 1. 关联的书籍 ID (通过索引快速查询某本书的所有书签)
  @Index()
  late int bookId;

  // 2. 位置信息
  int chapterIndex = 0;
  int charIndex = 0; // 章节内的偏移量

  // 3. 时间戳
  late DateTime timestamp;

  // 4. 预览文本
  late String previewText;

  // 用户备注
  String? note;
}