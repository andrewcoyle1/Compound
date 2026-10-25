import 'package:app_ui/app_ui.dart';

enum _Look { glyph, close, confirm, avatar }

/// {@template app_toolbar_button}
/// A button in an app bar, with a 44 pt tap target and its
/// [semanticLabel] as tooltip and screen-reader label.
///
/// - The default constructor is a bare glyph, such as Settings or Add,
///   with an optional count badge, such as the notifications bell's.
/// - [AppToolbarButton.close] is a modal's dismiss button, at the leading
///   edge. No "Cancel" text button.
/// - [AppToolbarButton.confirm] is a modal's confirm button, at the trailing
///   edge: a tick on an accent circle, a spinner while saving.
/// - [AppToolbarButton.avatar] is the tab roots' profile button: the user's
///   photo, else their initials, else the profile glyph.
///
/// Toolbar glyphs keep their size at large text sizes, as iOS's navigation
/// bar does; the tooltip shows the label on a long press.
/// {@endtemplate}
class AppToolbarButton extends StatelessWidget {
  /// A bare [icon].
  ///
  /// {@macro app_toolbar_button}
  const new({
    required IconData icon,
    required String semanticLabel,
    required VoidCallback? onPressed,
    int badgeCount = 0,
    Key? key,
  }) : this._(
         look: _Look.glyph,
         icon: icon,
         semanticLabel: semanticLabel,
         onPressed: onPressed,
         badgeCount: badgeCount,
         key: key,
       );

  /// A modal's close button. With no [onPressed] it pops the route.
  const new close({
    required String semanticLabel,
    VoidCallback? onPressed,
    Key? key,
  }) : this._(
         look: _Look.close,
         icon: AppSymbols.close,
         semanticLabel: semanticLabel,
         onPressed: onPressed,
         key: key,
       );

  /// A modal's confirm button. While [isSaving] it shows a spinner and is
  /// disabled; `null` [onPressed] disables it too, such as while the form
  /// is invalid.
  const new confirm({
    required String semanticLabel,
    required VoidCallback? onPressed,
    bool isSaving = false,
    Key? key,
  }) : this._(
         look: _Look.confirm,
         icon: AppSymbols.confirm,
         semanticLabel: semanticLabel,
         onPressed: onPressed,
         isSaving: isSaving,
         key: key,
       );

  /// The user's [image], else their [initials], else the profile glyph.
  const new avatar({
    required String semanticLabel,
    required VoidCallback? onPressed,
    ImageProvider? image,
    String? initials,
    Key? key,
  }) : this._(
         look: _Look.avatar,
         icon: AppSymbols.profile,
         semanticLabel: semanticLabel,
         onPressed: onPressed,
         image: image,
         initials: initials,
         key: key,
       );

  const new _({
    required this._look,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.isSaving = false,
    this.badgeCount = 0,
    this.image,
    this.initials,
    super.key,
  });

  final _Look _look;

  /// The glyph.
  final IconData icon;

  /// What the button does, localized.
  final String semanticLabel;

  /// Called when tapped.
  final VoidCallback? onPressed;

  /// Whether a confirm button's save is in progress.
  final bool isSaving;

  /// A glyph's count badge, such as unread notifications; hidden at zero.
  final int badgeCount;

  /// An avatar's photo.
  final ImageProvider? image;

  /// An avatar's initials, shown without a photo.
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onPressed = switch (_look) {
      _Look.close => this.onPressed ?? () => Navigator.maybePop(context),
      _Look.confirm when isSaving => null,
      _ => this.onPressed,
    };
    final glyph = AppIconSize.medium.points;
    final circle = IconButton.styleFrom(
      fixedSize: const Size.square(AppControlSize.compact),
      minimumSize: const Size.square(AppControlSize.compact),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.padded,
    );
    return switch (_look) {
      _Look.glyph || _Look.close => IconButton(
        onPressed: onPressed,
        tooltip: semanticLabel,
        iconSize: glyph,
        // The badge keeps its size at large text, as the glyph does.
        icon: Badge(
          label: Text('$badgeCount', textScaler: TextScaler.noScaling),
          isLabelVisible: badgeCount > 0,
          child: Icon(icon),
        ),
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size.square(AppControlSize.row),
        ),
      ),
      _Look.confirm => IconButton(
        onPressed: onPressed,
        tooltip: semanticLabel,
        iconSize: AppIconSize.small.points,
        icon: isSaving
            // The circle keeps its size at any text size, as the icon does.
            ? MediaQuery.withNoTextScaling(
                child: AppSpinner(
                  size: AppSpinnerSize.small,
                  color: scheme.onSurfaceVariant,
                ),
              )
            : Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
        ).merge(circle),
      ),
      _Look.avatar => IconButton(
        onPressed: onPressed,
        tooltip: semanticLabel,
        iconSize: AppControlSize.compact,
        icon: _Avatar(image: image, initials: initials, glyph: icon),
        style: circle,
      ),
    };
  }
}

class _Avatar extends StatelessWidget {
  const new({required this.image, required this.initials, required this.glyph});

  final ImageProvider? image;
  final String? initials;
  final IconData glyph;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final initials = this.initials;
    final fallback = initials == null || initials.isEmpty
        ? Icon(glyph, size: AppControlSize.compact)
        : CircleAvatar(
            backgroundColor: colors.raised,
            foregroundColor: scheme.onSurface,
            child: Text(
              initials,
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
              textScaler: TextScaler.noScaling,
            ),
          );
    final image = this.image;
    if (image == null) return fallback;
    return ClipOval(
      child: Image(
        image: image,
        width: AppControlSize.compact,
        height: AppControlSize.compact,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
