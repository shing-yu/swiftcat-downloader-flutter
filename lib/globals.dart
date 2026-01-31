import 'package:package_info_plus/package_info_plus.dart';

PackageInfo? globalPackageInfo;

Future<void> initGlobalPackageInfo() async {
  globalPackageInfo = await PackageInfo.fromPlatform();
}