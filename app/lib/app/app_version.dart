import 'package:package_info_plus/package_info_plus.dart';

/// The installed app's version and build (Swift `Utilities.appVersion` and
/// `buildNumber`), read once at launch.
class const AppVersion({
  /// `CFBundleShortVersionString` on iOS, `versionName` on Android.
  required final String version,

  /// `CFBundleVersion` on iOS, `versionCode` on Android.
  required final String build,
}) {
  /// What the platform says about this install.
  static Future<AppVersion> load() async {
    final info = await PackageInfo.fromPlatform();
    return AppVersion(version: info.version, build: info.buildNumber);
  }
}
