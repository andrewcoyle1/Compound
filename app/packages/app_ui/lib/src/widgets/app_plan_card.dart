import 'package:app_ui/app_ui.dart';

/// {@template app_plan_card}
/// One subscription plan to pick on a paywall: its [title], the billed
/// [price] in the display face with its [period] beside it, and an optional
/// [detail] line. The whole card is the tap target.
///
/// The chosen plan is outlined in the accent and carries an [AppDoneMark];
/// the others an empty circle. The mark carries the choice where volt is
/// faint (on white), and the card is announced as selected.
///
/// The price is the card's biggest text, as App Review asks of the billed
/// amount (guideline 3.1.2), and is never shrunk or cut short.
/// {@endtemplate}
class AppPlanCard extends StatelessWidget {
  /// {@macro app_plan_card}
  const new({
    required this.title,
    required this.price,
    required this.selected,
    required this.onPressed,
    this.period,
    this.detail,
    super.key,
  });

  /// The plan's name, such as `Pro Annual`.
  final String title;

  /// The billed amount, localized by the store, such as `£29.99`.
  final String price;

  /// The billing period after the price, such as `/ 1 year`.
  final String? period;

  /// A line about the plan.
  final String? detail;

  /// Whether this is the chosen plan.
  final bool selected;

  /// Called when the card is tapped, after a selection haptic.
  final VoidCallback? onPressed;

  /// The outline of the chosen plan.
  static const selectedOutline = 2.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final period = this.period;
    final detail = this.detail;
    final onPressed = this.onPressed;
    final onTap = onPressed == null
        ? null
        : () {
            AppHaptics.play(AppHaptic.selection).ignore();
            onPressed();
          };
    return Semantics(
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: title,
      value: [
        if (period == null) price else '$price $period',
        ?detail,
      ].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        color: colors.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.l)),
          side: selected
              ? BorderSide(color: colors.accentInk, width: selectedOutline)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Row(
            spacing: AppSpacing.m,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xxs,
                  children: [
                    Text(title, style: AppTextStyles.sectionTitle),
                    // The period moves under the price whole, rather
                    // than splitting, at large text sizes.
                    Wrap(
                      spacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(price, style: AppTextStyles.metricLarge),
                        if (period != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xxs,
                            ),
                            child: Text(
                              period,
                              style: AppTextStyles.rowDetail.secondary(context),
                            ),
                          ),
                      ],
                    ),
                    if (detail != null)
                      Text(
                        detail,
                        style: AppTextStyles.rowDetail.secondary(context),
                      ),
                  ],
                ),
              ),
              if (selected)
                const AppDoneMark()
              else
                ExcludeSemantics(
                  child: Icon(
                    AppSymbols.choiceUnselected,
                    size: AppIconSize.medium.of(context),
                    color: scheme.outline,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
