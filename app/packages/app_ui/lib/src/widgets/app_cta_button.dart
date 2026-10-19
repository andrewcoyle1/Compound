import 'package:app_ui/app_ui.dart';

/// The look of an [AppCtaButton].
enum AppCtaVariant {
  /// The screen's main action: an accent capsule.
  primary,

  /// Another action: a grey capsule.
  secondary,

  /// A quiet alternative such as "Skip for now": text only.
  plain,
}

/// {@template app_cta_button}
/// A full-width call-to-action button. Pin it to the bottom of a screen in an
/// [AppBottomCta]; a screen has one [AppCtaVariant.primary] at most.
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
        : Text(label);
    // As tall as Swift's call-to-action button.
    final filled = FilledButton.styleFrom(
      minimumSize: const Size(0, AppControlSize.cta),
    );
    final button = switch (variant) {
      AppCtaVariant.primary => FilledButton(
        onPressed: onPressed,
        style: filled,
        child: child,
      ),
      AppCtaVariant.secondary => FilledButton.tonal(
        onPressed: onPressed,
        style: filled,
        child: child,
      ),
      AppCtaVariant.plain => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
        child: child,
      ),
    };
    return Semantics(
      label: isLoading ? label : null,
      value: isLoading ? loadingLabel : null,
      child: SizedBox(width: double.infinity, child: button),
    );
  }
}
