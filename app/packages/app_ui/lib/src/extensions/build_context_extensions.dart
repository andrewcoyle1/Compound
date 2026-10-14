import 'package:app_ui/app_ui.dart';

/// Shortcuts to the theme's tokens.
extension AppThemeBuildContext on BuildContext {
  /// The [AppColors] of the current theme. The theme must come from
  /// [AppTheme].
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
