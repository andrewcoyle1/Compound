import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/nutrition/bloc/expenditure_estimate_bloc.dart';
import 'package:compound/settings/nutrition/cubit/strategy_settings_cubit.dart';
import 'package:compound/settings/nutrition/logic/nutrition_settings_labels.dart';
import 'package:compound/settings/nutrition/view/nutrition_settings_widgets.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';

/// How expenditure is estimated, with today's figure above the controls
/// that move it (Swift `ExpenditureSettingsView`). Every change saves at
/// once; it is the same document as Strategy.
class ExpenditureSettingsPage extends StatelessWidget {
  const new({super.key, this.now});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'expenditure';
  static const name = 'settingsExpenditure';

  /// The moment the estimate is for; now when null. For tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final uid = signedInUid(context);
    if (uid == null) return const SizedBox.shrink();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => StrategySettingsCubit(
            checkInRepository: context.read<CheckInRepository>(),
            analytics: context.read<AnalyticsRepository>(),
            uid: uid,
            screen: 'ExpenditureSettingsView',
          ),
        ),
        BlocProvider(
          create: (context) => ExpenditureEstimateBloc(
            checkInRepository: context.read<CheckInRepository>(),
            nutritionRepository: context.read<NutritionRepository>(),
            bodyRepository: context.read<BodyRepository>(),
            userRepository: context.read<UserRepository>(),
            uid: uid,
            now: now ?? DateTime.now,
          )..add(const ExpenditureEstimateSubscriptionRequested()),
        ),
      ],
      child: const ExpenditureSettingsView(),
    );
  }
}

class ExpenditureSettingsView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<StrategySettingsCubit>();
    final locale = Localizations.localeOf(context).toLanguageTag();
    ChoiceRow<T> picker<T>(
      String key,
      String title, {
      required T value,
      required List<T> options,
      required ({String title, String detail}) Function(T) describe,
    }) => ChoiceRow<T>(
      title: title,
      value: value,
      options: options,
      label: (option) => describe(option).title,
      subtitle: (option) => describe(option).detail,
      onChanged: (option) => unawaited(cubit.set(key, option)),
    );
    return SettingsDocumentScaffold<
      StrategySettingsCubit,
      NutritionStrategySettings
    >(
      title: l10n.expenditureSettingsTitle,
      sections: (context, s) {
        final start = s.calculationStartDate;
        return [
          const _EstimateSection(),
          AppSection(
            header: l10n.expenditureSettingsInitialHeader,
            children: [
              picker(
                NutritionStrategySettingsKeys.estimationMethod,
                l10n.expenditureSettingsEstimationMethod,
                value: s.estimationMethod,
                options: ExpenditureEstimationMethod.values,
                describe: (method) => switch (method) {
                  ExpenditureEstimationMethod.standard => (
                    title: l10n.expenditureSettingsStandard,
                    detail: l10n.expenditureSettingsStandardDetail,
                  ),
                  ExpenditureEstimationMethod.bodyFatAware => (
                    title: l10n.expenditureSettingsBodyFatAware,
                    detail: l10n.expenditureSettingsBodyFatAwareDetail,
                  ),
                },
              ),
              AppListRowButton(
                title: l10n.expenditureSettingsStartDate,
                accessory: AppListRowValue(
                  start == null
                      ? l10n.expenditureSettingsDefault
                      : DateFormat.yMMMd(locale).format(start.toLocal()),
                ),
                onPressed: () => unawaited(_chooseStartDate(context, start)),
              ),
              if (start != null)
                AppListRowButton(
                  title: l10n.expenditureSettingsUseDefault,
                  accessory: null,
                  onPressed: () => unawaited(
                    cubit.set(
                      NutritionStrategySettingsKeys.calculationStartDate,
                      null,
                    ),
                  ),
                ),
              picker(
                NutritionStrategySettingsKeys.bmrEquation,
                l10n.expenditureSettingsBmrEquation,
                value: s.bmrEquation,
                options: BmrEquation.values,
                describe: (equation) => switch (equation) {
                  BmrEquation.mifflinStJeor => (
                    title: l10n.expenditureSettingsMifflin,
                    detail: l10n.expenditureSettingsMifflinDetail,
                  ),
                  BmrEquation.harrisBenedict => (
                    title: l10n.expenditureSettingsHarris,
                    detail: l10n.expenditureSettingsHarrisDetail,
                  ),
                  BmrEquation.cunningham => (
                    title: l10n.expenditureSettingsCunningham,
                    detail: l10n.expenditureSettingsCunninghamDetail,
                  ),
                },
              ),
            ],
          ),
          AppSection(
            header: l10n.expenditureSettingsCalculationHeader,
            footer: l10n.expenditureSettingsCalculationFooter,
            children: [
              picker(
                NutritionStrategySettingsKeys.calculationMode,
                l10n.expenditureSettingsCalculationMode,
                value: s.calculationMode,
                options: ExpenditureCalculationMode.values,
                describe: (mode) => switch (mode) {
                  ExpenditureCalculationMode.dynamic => (
                    title: l10n.expenditureSettingsDynamic,
                    detail: l10n.expenditureSettingsDynamicDetail,
                  ),
                  ExpenditureCalculationMode.fixed => (
                    title: l10n.expenditureSettingsFixed,
                    detail: l10n.expenditureSettingsFixedDetail,
                  ),
                },
              ),
              picker(
                NutritionStrategySettingsKeys.algorithmVersion,
                l10n.expenditureSettingsAlgorithm,
                value: s.algorithmVersion,
                options: ExpenditureAlgorithmVersion.values,
                describe: (version) => switch (version) {
                  ExpenditureAlgorithmVersion.version1 => (
                    title: l10n.expenditureSettingsVersion1,
                    detail: l10n.expenditureSettingsVersion1Detail,
                  ),
                },
              ),
            ],
          ),
          AppSection(
            header: l10n.expenditureSettingsModifiersHeader,
            children: [
              AppListRowToggle(
                title: l10n.expenditureSettingsStepInformed,
                subtitle: l10n.expenditureSettingsStepInformedDetail,
                value: s.stepInformedUpdates,
                onChanged: (value) => unawaited(
                  cubit.set(
                    NutritionStrategySettingsKeys.stepInformedUpdates,
                    value,
                  ),
                ),
              ),
            ],
          ),
        ];
      },
    );
  }

  /// Picking a day is the whole choice, as in Swift; dismissing the picker
  /// keeps the date there was, and saves nothing.
  Future<void> _chooseStartDate(BuildContext context, DateTime? start) async {
    final cubit = context.read<StrategySettingsCubit>();
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start?.toLocal() ?? today,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked == null) return;
    await cubit.set(
      NutritionStrategySettingsKeys.calculationStartDate,
      DateTime(picked.year, picked.month, picked.day),
    );
  }
}

/// Today's figure and one line saying where it came from (Swift
/// `estimateSection`): "2,480 kcal" alone can't tell a month of logging
/// from a guess off the user's height.
class _EstimateSection extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final estimate = context
        .select<ExpenditureEstimateBloc, maths.ExpenditureEstimate?>(
          (bloc) => bloc.state.estimate,
        );
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    Text detail(String text, TextStyle style) =>
        Text(text, style: style.copyWith(color: secondary));
    return AppSection(
      header: l10n.expenditureSettingsTodayHeader,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: estimate == null
              ? const Center(child: CircularProgressIndicator.adaptive())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.xs,
                  children: [
                    Text(
                      l10n.expenditureSettingsKcal(estimate.kcal.round()),
                      style: AppTextStyles.metricLarge,
                    ),
                    if (likelyRange(estimate) case final range?)
                      detail(
                        l10n.expenditureSettingsLikely(range.low, range.high),
                        AppTextStyles.rowDetail,
                      ),
                    detail(switch (ExpenditureStatus.of(estimate)) {
                      ExpenditureFixed() => l10n.expenditureSettingsFixed,
                      ExpenditureCalibrating() =>
                        l10n.expenditureSettingsCalibrating(
                          ExpenditureCalibrating.minDays,
                          ExpenditureCalibrating.minWeighIns,
                        ),
                      ExpenditureAdaptive(
                        :final loggedDays,
                        :final windowDays,
                      ) =>
                        l10n.expenditureSettingsAdaptive(
                          loggedDays,
                          windowDays,
                        ),
                    }, AppTextStyles.rowDetail),
                    if (stepAdjustment(estimate) case final kcal?)
                      detail(
                        l10n.expenditureSettingsSteps(
                          kcal > 0 ? '+' : '−',
                          kcal.abs(),
                        ),
                        AppTextStyles.label,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
