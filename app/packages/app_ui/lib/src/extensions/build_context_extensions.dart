import 'package:app_ui/app_ui.dart';

/// Shortcuts to the theme's tokens.
extension AppThemeBuildContext on BuildContext {
  /// The [AppColors] of the current theme. The theme must come from
  /// [AppTheme].
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;

  /// Whether the window has room for two phone-width columns
  /// ([AppContentWidth.twoColumns]): a tablet, a desktop window or a large
  /// phone on its side. Flutter's stand-in for iOS's regular horizontal size
  /// class, for controls that move onto the bar when there is room.
  bool get isRegularWidth =>
      MediaQuery.sizeOf(this).width >= AppContentWidth.twoColumns;
}
