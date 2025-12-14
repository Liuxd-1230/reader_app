import 'dart:io';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

// 引入刚才定义的模型
import '../models/book.dart';
import '../models/bookmark.dart';

class DatabaseService {
  // 单例模式：确保全局只有一个数据库连接
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Isar _isar;

  // 对外暴露 isar 实例
  Isar get isar => _isar;

  /// 初始化数据库
  Future<void> init() async {
    // 获取 iOS/Android 的文档目录
    final dir = await getApplicationDocumentsDirectory();

    // 打开数据库，传入所有 Schema
    _isar = await Isar.open(
      [BookSchema, BookmarkSchema],
      directory: dir.path,
      inspector: true, // 开发模式下允许使用 Isar Inspector 查看数据
    );
  }
}