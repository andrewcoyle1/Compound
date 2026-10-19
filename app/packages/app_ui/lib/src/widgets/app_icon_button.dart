import 'package:app_ui/app_ui.dart';

/// {@template app_icon_button}
/// An icon-only button inside content, such as a row's edit pencil: the
/// glyph in the accent on a circle of the accent's tinted surface. The circle
/// is [AppControlSize.compact] across and grows with the text size; its tap
/// target is at least 44 pt.
///
/// In an app bar, use [AppToolbarButton].
/// {@endtemplate}
class AppIconButton extends StatelessWidget {
  /// {@macro app_icon_button}
  const new({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  /// The glyph, from [AppSymbols].
  final IconData icon;

  /// What the button does, localized: read by screen readers and shown as
  /// its tooltip.
  final String semanticLabel;

  /// Called when tapped. `null` disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diameter = MediaQuery.textScalerOf(context)
        .scale(AppControlSize.compact);
    return IconButton(
      onPressed: onPressed,
      tooltip: semanticLabel,
      iconSize: AppIconSize.small.of(context),
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.tintedSurface(scheme.primary),
        foregroundColor: scheme.primary,
        disabledBackgroundColor: scheme.surfaceContainerHighest,
        disabledForegroundColor: scheme.onSurfaceVariant,
        fixedSize: Size.square(diameter),
        minimumSize: Size.square(diameter),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
