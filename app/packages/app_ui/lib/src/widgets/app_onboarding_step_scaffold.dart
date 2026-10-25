import 'package:app_ui/app_ui.dart';

/// {@template app_onboarding_step_scaffold}
/// The shared shape of an onboarding step: a large title, an optional
/// progress bar and subtitle, the step's sections, and a primary call to
/// action (plus an optional plain one) pinned to the bottom.
///
/// Progress is a fraction (`0..1`), not "Step x of y": several sub-screens
/// share one step, and a fraction reads the same either way.
/// {@endtemplate}
class AppOnboardingStepScaffold extends StatelessWidget {
  /// {@macro app_onboarding_step_scaffold}
  const new({
    required this.title,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.subtitle,
    this.progress,
    this.progressLabel,
    this.isPrimaryLoading = false,
    this.loadingLabel,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.actions,
    this.onBack,
    this.children = const [],
    super.key,
  });

  /// The step's title.
  final String title;

  /// The primary button's text.
  final String primaryLabel;

  /// Called by the primary button. `null` disables it.
  final VoidCallback? onPrimaryPressed;

  /// A line under the progress bar.
  final String? subtitle;

  /// How far through onboarding this step is, `0..1`.
  final double? progress;

  /// The progress bar's name for screen readers, such as
  /// `Onboarding progress`.
  final String? progressLabel;

  /// Whether the primary action is in progress.
  final bool isPrimaryLoading;

  /// See [AppCtaButton.loadingLabel].
  final String? loadingLabel;

  /// A plain secondary button's text, such as `Skip for now`.
  final String? secondaryLabel;

  /// Called by the secondary button.
  final VoidCallback? onSecondaryPressed;

  /// App bar actions, such as developer settings in debug builds.
  final List<Widget>? actions;

  /// Called by a back button in the app bar, for a question inside a step
  /// that has one before it. No button when null.
  final VoidCallback? onBack;

  /// The step's content, usually [AppSection]s.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    final subtitle = this.subtitle;
    final secondaryLabel = this.secondaryLabel;
    // AppScaffold's large title: drawn in largeTitle above the content,
    // and in the app bar at the standard size once it scrolls away. A
    // SliverAppBar.large drew both from the app bar theme's title style.
    return AppScaffold(
      largeTitle: title,
      actions: actions,
      leading: onBack == null ? null : BackButton(onPressed: onBack),
      // Above the keyboard, as SwiftUI's safe-area inset is: a Scaffold
      // leaves its bottom bar under it.
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: AppBottomCta(
          children: [
            AppCtaButton(
              label: primaryLabel,
              onPressed: onPrimaryPressed,
              isLoading: isPrimaryLoading,
              loadingLabel: loadingLabel,
            ),
            if (secondaryLabel != null)
              AppCtaButton(
                label: secondaryLabel,
                onPressed: onSecondaryPressed,
                variant: AppCtaVariant.plain,
              ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.xl,
          children: [
            if (progress != null || subtitle != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.m,
                children: [
                  if (progress != null)
                    LinearProgressIndicator(
                      value: progress,
                      semanticsLabel: progressLabel,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AppRadius.s),
                      ),
                    ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: AppTextStyles.rowDetail.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}
