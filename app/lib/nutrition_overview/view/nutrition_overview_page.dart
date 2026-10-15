import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition_overview/bloc/nutrition_overview_bloc.dart';
import 'package:compound/nutrition_overview/logic/nutrition_overview.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';

/// The Nutrition Overview (Swift `NutritionOverviewView`), pushed from the
/// Nutrition tab for the day it shows: the weekly check-in's card or the
/// target proposal's, the day's calories and macros against its target,
/// the foods that contributed most, and its nutrients.
class NutritionOverviewPage extends StatelessWidget {
  const new({required this.dayKey, super.key});

  static const path = 'overview';
  static const name = 'nutritionOverview';

  /// The `yyyy-MM-dd` day shown; today without one.
  static const dayParameter = 'day';

  /// The day shown.
  final String dayKey;

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => NutritionOverviewBloc(
        users: context.read<UserRepository>(),
        nutrition: context.read<NutritionRepository>(),
        body: context.read<BodyRepository>(),
        checkIns: context.read<CheckInRepository>(),
        programs: context.read<ProgramRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        dismissals: context.read<ProposalDismissals>(),
        uid: state.user.uid,
        dayKey: dayKey,
      )..add(const NutritionOverviewStarted()),
      child: const NutritionOverviewView(),
    );
  }
}

class NutritionOverviewView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<NutritionOverviewBloc>().state;
    return BlocListener<NutritionOverviewBloc, NutritionOverviewState>(
      listenWhen: (previous, current) => previous.alertId != current.alertId,
      listener: (context, state) {
        unawaited(HapticFeedback.errorNotification());
        unawaited(
          showFailureAlert(context, switch (state.alert!) {
            NutritionOverviewAlert.acceptFailed =>
              l10n.nutritionOverviewUpdateFailed,
            NutritionOverviewAlert.skipFailed => l10n.checkInSkipFailed,
          }),
        );
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.nutritionOverviewTitle)),
        body: state.failed
            ? Center(
                child: Text(
                  l10n.nutritionDayLoadFailed,
                  style: AppTextStyles.sectionTitle,
                ),
              )
            : !state.isLoaded
            ? const Center(child: CircularProgressIndicator.adaptive())
            : _Overview(state: state),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const new({required this.state});

  final NutritionOverviewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final bloc = context.read<NutritionOverviewBloc>();
    final totals = state.totals;
    final target = state.target;
    final weekStart = state.dueCheckInWeekStart;
    final proposal = state.proposal;
    final top = state.showsContributors
        ? contributors(state.meals)
        : const <Contributor>[];
    final breakdown = nutrientBreakdown(state.meals);
    String grams(double value) => AppFormat.grams(value, locale: locale);
    double progress(double eaten, double? goal) =>
        goal == null || goal <= 0 ? 0 : (eaten / goal).clamp(0, 1);

    Widget macro(String title, double eaten, double? goal, Color color) =>
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.s,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.xs,
            children: [
              Row(
                spacing: AppSpacing.xs,
                children: [
                  Expanded(child: Text(title)),
                  Text(
                    eaten > 0 ? grams(eaten) : AppFormat.placeholder,
                    style: AppTextStyles.rowDetail.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (goal != null)
                    Text(
                      l10n.nutritionOverviewOfTarget(grams(goal)),
                      style: AppTextStyles.label,
                    ),
                ],
              ),
              LinearProgressIndicator(
                value: progress(eaten, goal),
                color: color,
              ),
            ],
          ),
        );

    final sections = <Widget>[
      if (weekStart != null)
        DecisionCard(
          title: l10n.nutritionOverviewCheckInReady,
          message: l10n.nutritionOverviewCheckInMessage,
          primary: l10n.checkInStart,
          onPrimary: () {
            bloc.add(const NutritionOverviewCheckInStarted());
            unawaited(CheckInPage.show(context, weekStart));
          },
          secondary: l10n.checkInSkipWeek,
          onSecondary: () => bloc.add(const NutritionOverviewCheckInSkipped()),
        ),
      if (proposal != null)
        DecisionCard(
          title: l10n.checkInNewTargets,
          message: ExpenditureText.proposal(l10n, proposal, locale: locale),
          primary: l10n.checkInAccept,
          onPrimary: () => bloc.add(const NutritionOverviewProposalAccepted()),
          secondary: l10n.nutritionOverviewNotNow,
          onSecondary: () =>
              bloc.add(const NutritionOverviewProposalDismissed()),
          info: MethodInfo.targetProposal(l10n),
        ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.l),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.nutritionOverviewCalories,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Text(
                  l10n.nutritionOverviewContributors,
                  style: AppTextStyles.rowDetail,
                ),
                Switch.adaptive(
                  value: state.showsContributors,
                  onChanged: (on) =>
                      bloc.add(NutritionOverviewContributorsToggled(on: on)),
                ),
              ],
            ),
          ),
          AppSection(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.s,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.nutritionOverviewConsumed(
                              AppFormat.kcal(
                                totals.calories.round(),
                                locale: locale,
                              ),
                            ),
                            style: AppTextStyles.sectionTitle,
                          ),
                        ),
                        if (target != null)
                          Text(
                            l10n.nutritionOverviewOfTarget(
                              AppFormat.kcal(
                                target.calories.round(),
                                locale: locale,
                              ),
                            ),
                            style: AppTextStyles.rowDetail,
                          ),
                      ],
                    ),
                    LinearProgressIndicator(
                      value: progress(totals.calories, target?.calories),
                      color: colors.calories,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      if (top.isNotEmpty)
        AppSection(
          header: l10n.nutritionOverviewTopContributors,
          children: [
            for (final food in top)
              AppListRow(
                title: food.name,
                subtitle: [
                  l10n.nutritionOverviewProtein(
                    grams(food.macros.proteinGrams),
                  ),
                  l10n.nutritionOverviewFat(grams(food.macros.fatGrams)),
                  l10n.nutritionOverviewCarbs(grams(food.macros.carbGrams)),
                ].join(' · '),
                accessory: AppListRowValue(
                  AppFormat.kcal(food.macros.calories.round(), locale: locale),
                ),
              ),
          ],
        ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s,
        children: [
          MethodInfoHeader(
            title: l10n.progressMacros,
            info: MethodInfo.macroSplit(l10n),
          ),
          AppSection(
            children: [
              macro(
                l10n.nutritionMacroProtein,
                totals.proteinGrams,
                target?.proteinGrams,
                colors.protein,
              ),
              macro(
                l10n.nutritionMacroCarbs,
                totals.carbGrams,
                target?.carbGrams,
                colors.carbs,
              ),
              macro(
                l10n.nutritionMacroFat,
                totals.fatGrams,
                target?.fatGrams,
                colors.fat,
              ),
            ],
          ),
        ],
      ),
      for (final section in NutrientSection.values)
        if (NutrientLine.values.any(
          (line) => line.section == section && breakdown.containsKey(line),
        ))
          AppSection(
            header: sectionTitle(l10n, section),
            children: [
              for (final line in NutrientLine.values)
                if (line.section == section)
                  if (breakdown[line] case final value?)
                    AppListRow(
                      title: nutrientName(l10n, line),
                      accessory: AppListRowValue(
                        AppFormat.nutrient(
                          value,
                          unit: line.unit,
                          locale: locale,
                        ),
                      ),
                    ),
            ],
          ),
    ];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        for (final (index, section) in sections.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.xl),
          section,
        ],
      ],
    );
  }
}

/// A section's header.
String sectionTitle(AppLocalizations l10n, NutrientSection section) =>
    switch (section) {
      NutrientSection.carbs => l10n.nutritionOverviewCarbBreakdown,
      NutrientSection.fats => l10n.nutritionOverviewFatBreakdown,
      NutrientSection.vitamins => l10n.nutritionOverviewVitamins,
      NutrientSection.minerals => l10n.nutritionOverviewMinerals,
      NutrientSection.other => l10n.nutritionOverviewOther,
    };

/// A nutrient's name.
String nutrientName(AppLocalizations l10n, NutrientLine line) => switch (line) {
  NutrientLine.fiber => l10n.nutrientFiber,
  NutrientLine.sugar => l10n.nutrientSugar,
  NutrientLine.netCarbs => l10n.nutrientNetCarbs,
  NutrientLine.saturated => l10n.nutrientSaturated,
  NutrientLine.monounsaturated => l10n.nutrientMonounsaturated,
  NutrientLine.polyunsaturated => l10n.nutrientPolyunsaturated,
  NutrientLine.vitaminA => l10n.nutrientVitaminA,
  NutrientLine.vitaminB6 => l10n.nutrientVitaminB6,
  NutrientLine.vitaminB12 => l10n.nutrientVitaminB12,
  NutrientLine.vitaminC => l10n.nutrientVitaminC,
  NutrientLine.vitaminD => l10n.nutrientVitaminD,
  NutrientLine.vitaminE => l10n.nutrientVitaminE,
  NutrientLine.vitaminK => l10n.nutrientVitaminK,
  NutrientLine.thiamin => l10n.nutrientThiamin,
  NutrientLine.riboflavin => l10n.nutrientRiboflavin,
  NutrientLine.niacin => l10n.nutrientNiacin,
  NutrientLine.pantothenicAcid => l10n.nutrientPantothenicAcid,
  NutrientLine.folate => l10n.nutrientFolate,
  NutrientLine.sodium => l10n.nutrientSodium,
  NutrientLine.potassium => l10n.nutrientPotassium,
  NutrientLine.calcium => l10n.nutrientCalcium,
  NutrientLine.iron => l10n.nutrientIron,
  NutrientLine.magnesium => l10n.nutrientMagnesium,
  NutrientLine.zinc => l10n.nutrientZinc,
  NutrientLine.copper => l10n.nutrientCopper,
  NutrientLine.manganese => l10n.nutrientManganese,
  NutrientLine.phosphorus => l10n.nutrientPhosphorus,
  NutrientLine.selenium => l10n.nutrientSelenium,
  NutrientLine.cholesterol => l10n.nutrientCholesterol,
  NutrientLine.caffeine => l10n.nutrientCaffeine,
};
