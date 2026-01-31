import 'package:flutter/material.dart';

// 响应式布局组件，根据屏幕宽度切换移动端/桌面端布局
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget desktopBody;

  const ResponsiveLayout({
    required this.mobileBody,
    required this.desktopBody,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return mobileBody; // 移动端布局
        } else {
          return desktopBody; // 桌面端布局
        }
      },
    );
  }
}