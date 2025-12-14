import 'dart:ui';
import 'package:flutter/material.dart';

class FrostedGlassContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool hasShadow;
  final double blur;
  final double opacity;
  final Color? glassColor;
  final Color? borderColor;

  const FrostedGlassContainer({
    super.key,
    this.width,
    this.height,
    required this.child,
    this.borderRadius,
    this.padding,
    this.hasShadow = true,
    this.blur = 25.0, // 增加模糊度，提升高级感
    this.opacity = 0.55,
    this.glassColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(20);
    // 智能判断底色
    final baseColor = glassColor ?? Colors.white;
    final isDarkBase = baseColor.computeLuminance() < 0.5;

    // 边框逻辑：深色玻璃用微亮白边，浅色玻璃用微暗白边
    final effectiveBorderColor = borderColor ??
        (isDarkBase ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.4));

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: hasShadow
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkBase ? 0.4 : 0.08), // 深色模式阴影更重
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          )
        ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: baseColor.withOpacity(opacity),
              borderRadius: br,
              border: Border.all(color: effectiveBorderColor, width: 1.0),
              // 细腻光泽感
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor.withOpacity(opacity + 0.08),
                  baseColor.withOpacity(opacity - 0.05 > 0 ? opacity - 0.05 : 0),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}