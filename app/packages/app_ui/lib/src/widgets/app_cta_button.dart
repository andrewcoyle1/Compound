import 'package:app_ui/app_ui.dart';

/// The look of an [AppCtaButton].
enum AppCtaVariant {
  /// The screen's main action: an accent capsule.
  primary,

  /// Another action: a capsule filled with the accent's tinted surface,
  /// its label in the accent, as Swift's `.bordered`. Never an outline.
  secondary,

  /// A quiet alternative such as "Skip for now": text only.
  plain,
}

/// The size of an [AppCtaButton].
enum AppCtaSize {
  /// 56 pt and full width: a screen's call to action in an [AppBottomCta].
  regular,

  /// [AppControlSize.compact] tall and as wide as its label: an inline
  /// button in a row or card, such as Follow, Accept, Decline, Nudge, Edit
  /// Profile or Restore. Its tap target stays at least 44 pt. Wrap it in
  /// `Expanded` to share a row's width.
  compact,
}

/// {@template app_cta_button}
/// A call-to-action button. A [AppCtaSize.regular] one is full width; pin it
/// to the bottom of a screen in an [AppBottomCta]. A screen has one regular
/// [AppCtaVariant.primary] at most.
///
/// While [isLoading] the label gives way to a spinner at the same height, the
/// button is disabled, and screen readers hear [loadingLabel].
/// {@endtemplate}
class AppCtaButton extends StatelessWidget {
  /// {@macro app_cta_button}
  const new({
    required this.label,
    required this.onPressed,
    this.variant = AppCtaVariant.primary,
    this.size = AppCtaSize.regular,
    this.isLoading = false,
    this.loadingLabel,
    super.key,
  });

  /// The button's text, localized.
  final String label;

  /// Called when tapped. `null` disables the button.
  final VoidCallback? onPressed;

  /// The button's look.
  final AppCtaVariant variant;

  /// The button's size.
  final AppCtaSize size;

  /// Whether the action is in progress.
  final bool isLoading;

  /// What screen readers hear while loading, such as `Loading`.
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onPressed = isLoading ? null : this.onPressed;
    final child = isLoading
        ? Stack(
            alignment: Alignment.center,
            children: [
              Opacity(opacity: 0, child: Text(label)),
              SizedBox.square(
                dimension: AppIconSize.small.of(context),
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    variant == AppCtaVariant.primary
                        ? scheme.onPrimary
                        : scheme.onSurface,
                  ),
                ),
              ),
            ],
          )
        : Text(label, textAlign: TextAlign.center);
    final compact = size == AppCtaSize.compact;
    final textStyle = compact
        ? AppTextStyles.rowDetail.copyWith(fontWeight: FontWeight.w600)
        : null;
    final padding = compact
        ? const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.xs,
          )
        : null;
    // Regular is as tall as Swift's call-to-action button. A compact button
    // stays 32 pt to the eye but not to the finger.
    ButtonStyle filled({Color? background, Color? foreground}) =>
        FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          minimumSize: Size(
            0,
            compact ? AppControlSize.compact : AppControlSize.cta,
          ),
          textStyle: textStyle,
          padding: padding,
          tapTargetSize: MaterialTapTargetSize.padded,
        );
    final button = switch (variant) {
      AppCtaVariant.primary => FilledButton(
        onPressed: onPressed,
        style: filled(),
        child: child,
      ),
      AppCtaVariant.secondary => FilledButton(
        onPressed: onPressed,
        style: filled(
          background: AppColors.tintedSurface(scheme.primary),
          foreground: scheme.primary,
        ),
        child: child,
      ),
      AppCtaVariant.plain => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          // A regular plain button keeps the theme's 44 pt.
          minimumSize: compact ? const Size(0, AppControlSize.compact) : null,
          textStyle: textStyle,
          padding: padding,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        child: child,
      ),
    };
    return Semantics(
      label: isLoading ? label : null,
      value: isLoading ? loadingLabel : null,
      child: compact ? button : SizedBox(width: double.infinity, child: button),
    );
  }
}
