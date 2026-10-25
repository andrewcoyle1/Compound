import 'package:app_ui/app_ui.dart';

/// {@template app_icon_button}
/// An icon-only button inside content, such as a row's edit pencil: the
/// glyph in the accent on a circle of the accent's tinted surface, or in
/// `danger` on danger's tinted surface when [isDestructive]. The circle
/// is [AppControlSize.compact] across and grows with the text size; its tap
/// target is at least 44 pt.
///
/// [AppIconButton.plain] is a quieter glyph with no circle, for a row of
/// actions such as a feed card's Like, Comment, Share and More.
///
/// In an app bar, use [AppToolbarButton].
/// {@endtemplate}
class AppIconButton extends StatelessWidget {
  /// {@macro app_icon_button}
  const new({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.isDestructive = false,
    super.key,
  }) : label = null,
       selected = false,
       _plain = false;

  /// A bare glyph in `onSurfaceVariant`, or the accent when [selected], with
  /// an optional [label] after it, such as a like count. No circle; the tap
  /// target is at least 44 pt.
  ///
  /// {@macro app_icon_button}
  const new plain({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.label,
    this.selected = false,
    super.key,
  }) : isDestructive = false,
       _plain = true;

  /// The glyph, from [AppSymbols].
  final IconData icon;

  /// What the button does, localized: read by screen readers and shown as
  /// its tooltip.
  final String semanticLabel;

  /// Called when tapped. `null` disables the button.
  final VoidCallback? onPressed;

  /// A plain button's text after the glyph, such as a count; read by screen
  /// readers as the button's value.
  final String? label;

  /// Whether a plain button's state is on, such as a like: the glyph and
  /// label take the accent.
  final bool selected;

  final bool _plain;

  /// Whether the button deletes or removes something.
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_plain) return _buildPlain(context, scheme);
    // Neutral, the text colour on `raised`: a small control in a row is not
    // the screen's action, so it does not take the accent.
    final colors = context.appColors;
    final background = isDestructive
        ? AppColors.tintedSurface(colors.danger)
        : colors.raised;
    final foreground = isDestructive ? colors.danger : scheme.onSurface;
    final diameter = MediaQuery.textScalerOf(context)
        .scale(AppControlSize.compact);
    return IconButton(
      onPressed: onPressed,
      tooltip: semanticLabel,
      iconSize: AppIconSize.small.of(context),
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: scheme.surfaceContainerHighest,
        disabledForegroundColor: scheme.onSurfaceVariant,
        fixedSize: Size.square(diameter),
        minimumSize: Size.square(diameter),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }

  Widget _buildPlain(BuildContext context, ColorScheme scheme) {
    final color = selected
        ? context.appColors.accentInk
        : scheme.onSurfaceVariant;
    final label = this.label;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      value: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: semanticLabel,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Opacity(
            opacity: onPressed == null ? AppListRow.disabledOpacity : 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AppControlSize.row,
                minHeight: AppControlSize.row,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: AppSpacing.xs,
                  children: [
                    Icon(
                      icon,
                      size: AppIconSize.small.of(context),
                      color: color,
                    ),
                    if (label != null)
                      Text(
                        label,
                        style: AppTextStyles.rowDetail.copyWith(color: color),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
