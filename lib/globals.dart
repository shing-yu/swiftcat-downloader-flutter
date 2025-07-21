import 'package:package_info_plus/package_info_plus.dart';

/// 全局应用版本信息
PackageInfo? globalPackageInfo;

/// 初始化全局版本信息
Future<void> initGlobalPackageInfo() async {
  globalPackageInfo = await PackageInfo.fromPlatform();
}