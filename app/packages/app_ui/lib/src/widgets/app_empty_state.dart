import 'package:app_ui/app_ui.dart';

/// {@template app_empty_state}
/// What a screen or section shows when it has nothing to show (Swift's
/// `ContentUnavailableView`): a large [icon], a [title], a [description]
/// and, where there is one, the action that fills it, such as "Log a
/// Meal". Centred, it scrolls when the text is too large to fit.
///
/// For a failure use [AppErrorState].
/// {@endtemplate}
class AppEmptyState extends StatelessWidget {
  /// {@macro app_empty_state}
  const new({
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'Give actionLabel and onAction together.',
       );

  /// The concept that is missing, from [AppSymbols].
  final IconData icon;

  /// What is missing, localized: "No Meals Logged".
  final String title;

  /// Why, or what to do about it, localized.
  final String? description;

  /// The action's label, localized.
  final String? actionLabel;

  /// Called when the action is tapped.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final description = this.description;
    final actionLabel = this.actionLabel;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s,
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: AppIconSize.large.of(context),
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (description != null)
              Text(
                description,
                textAlign: TextAlign.center,
                style: AppTextStyles.rowDetail.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.s),
              // As wide as its label: a capsule, not a full-width CTA.
              IntrinsicWidth(
                child: AppCtaButton(
                  label: actionLabel,
                  onPressed: onAction,
                  variant: AppCtaVariant.secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// {@template app_error_state}
/// What a screen or section shows when loading it failed: an [AppEmptyState]
/// with the error glyph, announced to screen readers as it appears, and the
/// way out, usually "Try Again".
/// {@endtemplate}
class AppErrorState extends StatelessWidget {
  /// {@macro app_error_state}
  const new({
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.icon = AppSymbols.error,
    super.key,
  });

  /// What failed, localized: "Couldn't Load Your Meals".
  final String title;

  /// Why, or what to try, localized.
  final String? description;

  /// The action's label, localized: usually "Try Again".
  final String? actionLabel;

  /// Called when the action is tapped: usually a retry.
  final VoidCallback? onAction;

  /// The glyph, [AppSymbols.error] unless the failure has its own concept.
  final IconData icon;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: AppEmptyState(
      icon: icon,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}
