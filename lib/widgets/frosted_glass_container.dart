import 'dart:ui';
import 'package:flutter/material.dart';

class FrostedGlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  const FrostedGlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final _borderRadius = borderRadius ?? BorderRadius.circular(20.0);

    return Container(
      width: width,
      height: height,
      // 1. 阴影层：保持柔和，增加一点点扩展，让玻璃看起来更厚
      decoration: BoxDecoration(
        borderRadius: _borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), //稍微加深一点
            blurRadius: 20,
            spreadRadius: 2, // 扩散一点
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _borderRadius,
        child: BackdropFilter(
          // 2. 模糊层：加大模糊力度，从 15 提升到 20，质感更奶油
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: _borderRadius,
              // 3. 边框层：模拟玻璃边缘高光
              border: Border.all(
                color: Colors.white.withOpacity(0.4), // 边框更亮一点
                width: 1.5,
              ),
              // 4. 表面光感层：关键修改！使用线性渐变模拟光源反射
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  // 左上角更白（反光），右下角更透（阴影）
                  Colors.white.withOpacity(0.55),
                  Colors.white.withOpacity(0.25),
                ],
                // 调整光照角度
                stops: const [0.0, 1.0],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}