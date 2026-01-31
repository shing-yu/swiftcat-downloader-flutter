import 'package:package_info_plus/package_info_plus.dart';

// 全局包信息，存储应用版本等
PackageInfo? globalPackageInfo;

// 初始化全局包信息
Future<void> initGlobalPackageInfo() async {
  globalPackageInfo = await PackageInfo.fromPlatform();
}