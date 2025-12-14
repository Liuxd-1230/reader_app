import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 用于设置状态栏颜色
import 'data/services/database_service.dart';
import 'screens/library_screen.dart'; // 引入新写的页面
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 新增

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService().init();

  // 设置状态栏透明，让背景图透上去
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const MyApp());
  runApp(
    // 关键：包裹 ProviderScope
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iOS Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LibraryScreen(),
    );
  }
}