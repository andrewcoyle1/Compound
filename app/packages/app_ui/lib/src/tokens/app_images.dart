import 'package:material_ui/material_ui.dart';

/// Brand images bundled with the design system.
abstract final class AppImages {
  /// The app icon's artwork in its light appearance (Swift's
  /// `AppIconInternalDefaultAsset`), square with its own background. One
  /// resolution, 144 px, so a 24-point mark stays sharp at 3× and an
  /// off-screen render finds it under the same cache key.
  static const appIcon = AssetImage('assets/app_icon.png', package: 'app_ui');
}
