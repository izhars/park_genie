import 'package:package_info_plus/package_info_plus.dart';

class AppInfoUtil {
  static Future<String> getVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return 'Version ${packageInfo.version}+${packageInfo.buildNumber}';
  }
}
