import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/goal/goal_setup_cubit.dart';
import 'package:compound/onboarding/logic/body_units.dart';
import 'package:compound/onboarding/logic/goal_rules.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/onboarding/view/onboarding_labels.dart';
import 'package:compound/onboarding/view/onboarding_widgets.dart';
import 'package:compound/widgets/number_wheel.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:user_repository/user_repository.dart';

/// Setting the first goal: objective, target weight, weekly rate, summary.
class GoalSetupPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    final profile = state.profile;
    if (profile == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) {
        final cubit = GoalSetupCubit(
          userRepository: context.read<UserRepository>(),
          bodyRepository: context.read<BodyRepository>(),
          analyticsRepository: context.read<AnalyticsRepository>(),
          profile: profile,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const GoalSetupView(),
    );
  }
}

class GoalSetupView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<GoalSetupCubit>();
    final state = context.watch<GoalSetupCubit>().state;
    final onBack = state.question == GoalQuestion.objective ? null : cubit.back;
    final objective = state.objective;

    final question = state.status == GoalSetupStatus.loading
        ? const Scaffold(
            body: Center(child: CircularProgressIndicator.adaptive()),
          )
        : switch (state.question) {
            GoalQuestion.objective => OnboardingQuestion(
              step: OnboardingStep.goalSetting,
              title: l10n.onboardingObjectiveTitle,
              subtitle: l10n.onboardingObjectiveSubtitle,
              onContinue: state.canContinueObjective
                  ? cubit.objectiveContinued
                  : null,
              children: [
                OnboardingOptions<OverarchingObjective>(
                  options: OverarchingObjective.values,
                  selected: objective,
                  title: (objective) => objective.label(l10n),
                  subtitle: (objective) => objective.detail(l10n),
                  onSelected: cubit.objectiveSelected,
                ),
              ],
            ),
            GoalQuestion.targetWeight => OnboardingQuestion(
              step: OnboardingStep.goalSetting,
              title: l10n.onboardingTargetTitle,
              onBack: onBack,
              onContinue: state.canContinueTarget
                  ? cubit.targetContinued
                  : null,
              children: _target(context, state),
            ),
            GoalQuestion.rate => OnboardingQuestion(
              step: OnboardingStep.goalSetting,
              title: l10n.onboardingRateTitle,
              onBack: onBack,
              onContinue: cubit.rateContinued,
              children: _rate(context, state),
            ),
            GoalQuestion.summary => OnboardingQuestion(
              step: OnboardingStep.goalSetting,
              title: l10n.onboardingSummaryTitle,
              onBack: onBack,
              isLoading:
                  state.status == GoalSetupStatus.saving ||
                  state.status == GoalSetupStatus.saved,
              onContinue: cubit.save,
              children: _summary(context, state),
            ),
          };

    return BlocListener<GoalSetupCubit, GoalSetupState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, current) {
        if (current.status == GoalSetupStatus.saved) onboardingSaved();
        if (current.status == GoalSetupStatus.failure) {
          unawaited(
            showOnboardingFailure(
              context,
              title: l10n.onboardingUnableToSaveGoal,
              message: current.currentKg == null
                  ? l10n.onboardingNoCurrentWeight
                  : null,
            ),
          );
        }
      },
      child: PopScope(
        canPop: onBack == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) cubit.back();
        },
        child: question,
      ),
    );
  }

  static String _weight(
    BuildContext context,
    double kilograms,
    WeightUnitPreference unit, {
    int maxFractionDigits = 1,
  }) => AppFormat.weight(
    kilograms,
    unit == WeightUnitPreference.pounds
        ? AppWeightUnit.pounds
        : AppWeightUnit.kilograms,
    maxFractionDigits: maxFractionDigits,
    locale: Localizations.localeOf(context).toLanguageTag(),
  );

  List<Widget> _target(BuildContext context, GoalSetupState state) {
    final l10n = context.l10n;
    final cubit = context.read<GoalSetupCubit>();
    final range = state.targetRange!;
    final pounds = state.weightUnit == WeightUnitPreference.pounds;
    final heightFloor = lowestHealthyKilograms(state.heightCm);
    String? message;
    if (state.objective == OverarchingObjective.loseWeight &&
        heightFloor != null) {
      final current = state.currentKg ?? 0;
      message =
          current > 0 && range.min >= (pounds ? kgToLbs(current) : current)
          ? l10n.onboardingAlreadyUnderweight
          : l10n.onboardingLowestTarget(
              pounds ? '${range.min} lb' : '${range.min} kg',
            );
    }
    return [
      AppSection(
        header: pounds ? l10n.onboardingImperial : l10n.onboardingMetric,
        children: [
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(150),
            child: NumberWheel(
              key: ValueKey(range),
              label: l10n.onboardingTargetLabel,
              values: [for (var v = range.min; v <= range.max; v++) v],
              selected: state.targetWheel,
              itemLabel: pounds
                  ? l10n.onboardingPoundsValue
                  : l10n.onboardingKilogramsValue,
              onChanged: cubit.targetWheelChanged,
            ),
          ),
        ],
      ),
      if (message != null)
        AppInlineMessage(
          kind: AppInlineMessageKind.info,
          text: message,
          kindLabel: l10n.infoLabel,
        ),
    ];
  }

  List<Widget> _rate(BuildContext context, GoalSetupState state) {
    final l10n = context.l10n;
    final cubit = context.read<GoalSetupCubit>();
    final rules = state.rateRules!;
    final objective = state.objective!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final unit = state.weightUnit;
    final rate = state.rateKg;
    final current = rules.currentKg;
    final sign = objective == OverarchingObjective.loseWeight ? '-' : '+';
    final unitSymbol = unit == WeightUnitPreference.pounds ? 'lb' : 'kg';
    final two = NumberFormat('0.00', locale);
    final one = NumberFormat('0.0', locale);
    String change(double kilograms) {
      final amount = unit == WeightUnitPreference.pounds
          ? kgToLbs(kilograms)
          : kilograms;
      return two.format(amount);
    }

    final category = rules.isAggressive(rate)
        ? l10n.onboardingRateAggressive
        : rules.isConservative(rate)
        ? l10n.onboardingRateConservative
        : l10n.onboardingRateStandard;
    final warning = !rules.isAggressive(rate)
        ? null
        : switch (objective) {
            OverarchingObjective.loseWeight => l10n.onboardingRateLossWarning,
            OverarchingObjective.gainWeight => l10n.onboardingRateGainWarning,
            OverarchingObjective.maintain => null,
          };
    final weekly = l10n.onboardingWeeklyChange(
      sign,
      change(rate),
      unitSymbol,
      one.format(rate / current * 100),
    );
    final monthly = l10n.onboardingMonthlyChange(
      sign,
      change(rate * 4),
      unitSymbol,
      one.format(rate * 4 / current * 100),
    );
    final target = estimatedCalorieTarget(
      objective,
      rateKg: rate,
      expenditureKcal: state.expenditureKcal,
      floorKcal: state.floorKcal,
    );
    final distance = (state.targetKg - current).abs();
    final step = (targetChangeKcal(distance) / 10).round() * 10;
    final weeks = goalWeeks(
      distanceKg: state.targetKg - current,
      weeklyRateKg: rate,
    );
    final steps = ((rules.maximum - rules.minimum) / GoalTimeline.rateStep)
        .round();
    return [
      AppSection(
        header: l10n.onboardingWeeklyRate,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.m,
              children: [
                Text(category, style: AppTextStyles.sectionTitle),
                Slider.adaptive(
                  value: rate.clamp(rules.minimum, rules.maximum),
                  min: rules.minimum,
                  max: rules.maximum,
                  divisions: steps > 0 ? steps : null,
                  semanticFormatterCallback: (_) => weekly,
                  onChanged: cubit.rateChanged,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _weight(
                        context,
                        rules.minimum,
                        unit,
                        maxFractionDigits: 2,
                      ),
                      style: AppTextStyles.label,
                    ),
                    Text(
                      _weight(
                        context,
                        rules.maximum,
                        unit,
                        maxFractionDigits: 2,
                      ),
                      style: AppTextStyles.label,
                    ),
                  ],
                ),
                if (warning != null)
                  AppInlineMessage(
                    kind: AppInlineMessageKind.warning,
                    text: warning,
                    kindLabel: l10n.warningLabel,
                  ),
              ],
            ),
          ),
        ],
      ),
      AppSection(
        children: [
          AppListRow(title: weekly),
          AppListRow(title: monthly),
        ],
      ),
      AppSection(
        header: l10n.onboardingTargetAndTimeline,
        children: [
          AppListRow(
            title: l10n.onboardingEstimatedTarget('${target.kcal.round()}'),
          ),
          if (target.isDeficitCapped)
            AppListRow(title: l10n.onboardingDeficitCapped),
          AppListRow(
            title: weeks > 0
                ? l10n.onboardingEndDate(
                    DateFormat.yMMMd(locale)
                        .format(DateTime.now().add(Duration(days: weeks * 7))),
                  )
                : l10n.onboardingNoEndDate,
          ),
          if (distance > 0)
            AppListRow(
              title: objective == OverarchingObjective.loseWeight
                  ? l10n.onboardingStepDown('$step')
                  : l10n.onboardingStepUp('$step'),
            ),
        ],
      ),
    ];
  }

  List<Widget> _summary(BuildContext context, GoalSetupState state) {
    final l10n = context.l10n;
    final objective = state.objective!;
    final unit = state.weightUnit;
    final current = state.currentKg;
    final difference = current == null ? 0.0 : state.targetKg - current;
    final weeks = goalWeeks(distanceKg: difference, weeklyRateKg: state.rateKg);
    final months = (weeks / 4.33).ceil();
    final rate = _weight(context, state.rateKg, unit);
    return [
      AppSection(
        header: l10n.onboardingGoalOverview,
        children: [
          AppListRow(
            title: objective.label(l10n),
            subtitle: objective.detail(l10n),
          ),
        ],
      ),
      AppSection(
        header: l10n.onboardingWeightDetails,
        children: [
          if (current != null)
            AppListRow(
              title: l10n.onboardingCurrentWeight,
              accessory: AppListRowValue(_weight(context, current, unit)),
            ),
          AppListRow(
            title: l10n.onboardingTargetLabel,
            accessory: AppListRowValue(_weight(context, state.targetKg, unit)),
          ),
          if (difference != 0) ...[
            AppListRow(
              title: l10n.onboardingWeightChange,
              accessory: AppListRowValue(
                '${difference > 0 ? '+' : '−'}'
                '${_weight(context, difference.abs(), unit)}',
              ),
            ),
            AppListRow(
              title: l10n.onboardingWeeklyRate,
              accessory: AppListRowValue(l10n.onboardingPerWeek(rate)),
            ),
          ],
        ],
      ),
      AppSection(
        header: l10n.onboardingTimeline,
        footer: weeks > 0 ? l10n.onboardingTimelineDetail(rate) : null,
        children: [
          AppListRow(
            title: l10n.onboardingEstimatedTimeline,
            subtitle: weeks > 0
                ? l10n.onboardingTimelineValue(weeks, months)
                : l10n.onboardingMaintaining,
          ),
        ],
      ),
      AppSection(
        header: l10n.onboardingMotivation,
        children: [
          AppListRow(
            title: l10n.onboardingYouveGotThis,
            subtitle: switch (objective) {
              OverarchingObjective.loseWeight => l10n.onboardingMotivationLose,
              OverarchingObjective.maintain =>
                l10n.onboardingMotivationMaintain,
              OverarchingObjective.gainWeight => l10n.onboardingMotivationGain,
            },
          ),
        ],
      ),
    ];
  }
}
