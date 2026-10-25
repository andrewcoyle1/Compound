import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/progress/view/card_charts.dart';
import 'package:compound/progress/view/progress_card.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/training_analytics/bloc/training_analytics_bloc.dart';
import 'package:compound/training_analytics/logic/training_analytics.dart';
import 'package:compound/training_analytics/view/training_analytics_widgets.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound_maths/compound_maths.dart' show VolumeTier;
import 'package:compound_models/compound_models.dart' show Muscles;
import 'package:flutter_bloc/flutter_bloc.dart';

/// Weekly hard sets per muscle against the volume tiers, as a grid (Swift
/// `MuscleBalanceView`). Each tile carries its tier as a colour, an icon
/// and a word, so it never rests on colour alone. Tapping one shows its
/// twelve-week trend.
class MuscleBalancePage extends StatelessWidget {
  const new({super.key});

  /// The path under the Progress tab.
  static const path = 'muscle-balance';

  /// The route name.
  static const name = 'muscleBalance';

  @override
  Widget build(BuildContext context) => const TrainingAnalyticsProvider(
    screen: TrainingAnalyticsScreen.muscleBalance,
    child: MuscleBalanceView(),
  );
}

class MuscleBalanceView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.muscleBalanceTitle),
        actions: [MethodInfoButton(MethodInfo.weeklyVolumeTiers(l10n))],
      ),
      body: TrainingAnalyticsBody(
        title: l10n.muscleBalanceTitle,
        loaded: (state) {
          final weekly = state.weeklySetsByMuscle;
          Widget region(String header, {required bool upper}) {
            final muscles = [
              for (final muscle in Muscles.values)
                if (isUpperBody(muscle) == upper) muscle,
            ];
            final selected = state.selectedMuscle;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.s,
                children: [
                  AnalyticsSectionHeader(title: header),
                  ProgressCardGrid(
                    children: [
                      for (final muscle in muscles)
                        _Tile(
                          muscle: muscle,
                          sets: weekly[muscle]!.last,
                          isSelected: muscle == selected,
                        ),
                    ],
                  ),
                  if (selected != null && muscles.contains(selected))
                    _Trend(
                      muscle: selected,
                      weeks: weekly[selected]!,
                      today: state.today,
                    ),
                  // Under the last region only.
                  if (!upper)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: AppSpacing.l,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.muscleBalanceFooter,
                              style: AppTextStyles.label.secondary(context),
                            ),
                          ),
                          MethodInfoButton(MethodInfo.weeklyHardSets(l10n)),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }

          final productive = weekly.values
              .where(
                (weeks) => VolumeTier.of(weeks.last) == VolumeTier.productive,
              )
              .length;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              // The hero: how many muscles get a productive week's sets.
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                child: AppHeroStat(
                  label: l10n.progressLast7Days,
                  value:
                      '${AppFormat.number(productive)}/'
                      '${AppFormat.number(weekly.length)}',
                  unit: l10n.trainingMusclesProductiveUnit,
                ),
              ),
              region(l10n.muscleRegionUpper, upper: true),
              region(l10n.muscleRegionLower, upper: false),
            ],
          );
        },
      ),
    );
  }
}

/// A tier's word (Swift `MuscleBalanceStatus.label`).
String tierLabel(AppLocalizations l10n, VolumeTier tier) => switch (tier) {
  VolumeTier.belowMaintenance => l10n.tierBelowMaintenance,
  VolumeTier.maintaining => l10n.tierMaintaining,
  VolumeTier.productive => l10n.tierProductive,
  VolumeTier.high => l10n.tierHigh,
};

/// What a tier means, for the line under a muscle's trend.
String tierExplanation(AppLocalizations l10n, VolumeTier tier) =>
    switch (tier) {
      VolumeTier.belowMaintenance => l10n.tierBelowMaintenanceDetail,
      VolumeTier.maintaining => l10n.tierMaintainingDetail,
      VolumeTier.productive => l10n.tierProductiveDetail,
      VolumeTier.high => l10n.tierHighDetail,
    };

IconData _icon(VolumeTier tier) => switch (tier) {
  VolumeTier.belowMaintenance => AppSymbols.reduce,
  VolumeTier.maintaining => AppSymbols.steady,
  VolumeTier.productive => AppSymbols.success,
  VolumeTier.high => AppSymbols.increase,
};

/// Below maintenance and high are both "attention": the icon and the word
/// tell them apart.
Color _color(BuildContext context, VolumeTier tier) => switch (tier) {
  VolumeTier.belowMaintenance || VolumeTier.high => context.appColors.warning,
  VolumeTier.maintaining => Theme.of(context).colorScheme.onSurfaceVariant,
  VolumeTier.productive => context.appColors.success,
};

class _Tile extends StatelessWidget {
  const new({
    required this.muscle,
    required this.sets,
    required this.isSelected,
  });

  final Muscles muscle;
  final double sets;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final tier = VolumeTier.of(sets);
    final color = _color(context, tier);
    final name = l10n.muscleName(muscle);
    final value = setsText(l10n, sets, locale);
    final label = tierLabel(l10n, tier);
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$name, $value, $label',
      value: l10n.muscleBalanceRange(
        AppFormat.repRange(
          VolumeTier.productiveLow.round(),
          VolumeTier.productiveHigh.round(),
          locale: locale,
        ),
      ),
      excludeSemantics: true,
      child: AppPressable(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.l)),
        ),
        onTap: () => context.read<TrainingAnalyticsBloc>().add(
          TrainingAnalyticsMuscleToggled(muscle),
        ),
        child: AppSelectionRing(
          selected: isSelected,
          radius: AppRadius.l,
          // A plain tile: the tier's colour marks its glyph only, beside
          // the word, so status never tints a whole surface.
          child: AppCard(
            style: AppCardStyle.tile,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: SizedBox(
                width: double.infinity,
                child: AppStat(
                  value: value,
                  label: '$name · $label',
                  icon: _icon(tier),
                  tint: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A muscle's last twelve weeks of sets, each week plotted at the day it
/// ends, and what its tier means.
class _Trend extends StatelessWidget {
  const new({required this.muscle, required this.weeks, required this.today});

  final Muscles muscle;
  final List<double> weeks;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tier = VolumeTier.of(weeks.last);
    final name = l10n.muscleName(muscle);
    return AppCard(
      style: AppCardStyle.tile,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.s,
          children: [
            Text(
              l10n.muscleBalanceTrendTitle(name),
              style: AppTextStyles.sectionTitle,
            ),
            SizedBox(
              height: ProgressCard.chartHeight * 2,
              child: Sparkline(
                points: [
                  for (final (i, sets) in weeks.indexed)
                    (
                      date: DateTime(
                        today.year,
                        today.month,
                        today.day - 7 * (weeks.length - 1 - i),
                      ),
                      value: sets,
                    ),
                ],
                color: _color(context, tier),
                semanticsLabel: l10n.muscleBalanceTrendTitle(name),
              ),
            ),
            Text(
              tierExplanation(l10n, tier),
              style: AppTextStyles.label.secondary(context),
            ),
          ],
        ),
      ),
    );
  }
}
