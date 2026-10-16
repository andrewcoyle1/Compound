import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_tracker/cubit/plate_calculator_cubit.dart';
import 'package:compound/workout_tracker/view/plate_loading_view.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the plate calculator on [setup]; the gym as edited on Done, or
/// `null` when closed.
Future<GymProfileModel?> showPlateCalculator(
  BuildContext context,
  PlateCalculatorSetup setup,
) => showModalBottomSheet<GymProfileModel>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => BlocProvider(
    create: (context) => PlateCalculatorCubit(
      setup,
      analytics: context.read<AnalyticsRepository>(),
    ),
    child: const PlateCalculatorView(),
  ),
);

/// The plate calculator (`PlateCalculatorView`): the set's weight on the
/// bar, the bar the gym loads, and the plates it has. Done saves both to the
/// gym; Close discards them.
class PlateCalculatorView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<PlateCalculatorCubit>();
    final state = context.watch<PlateCalculatorCubit>().state;
    final unit = TrackerText.unit(state.unit);
    String weight(double value) =>
        '${TrackerText.amount(value, locale: locale)} $unit';
    final step = state.step;
    final loading = state.loading;
    final notLoadable = state.notLoadable;
    final bars = state.barChoices;
    final base = step.baseWeight;
    final load = state.load;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
          child: Row(
            children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(AppSymbols.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Column(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.plateCalculatorTitle,
                        style: AppTextStyles.rowTitle.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (load != null)
                      Text(
                        weight(load),
                        style: AppTextStyles.rowDetail.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppControlSize.row),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              if (loading != null)
                PlateLoadingView(
                  loading: loading,
                  plates: step.plates,
                  unit: state.unit,
                )
              else if (notLoadable != null)
                Row(
                  spacing: AppSpacing.s,
                  children: [
                    Icon(AppSymbols.warning, color: context.appColors.danger),
                    Expanded(
                      child: Text(
                        TrackerText.notLoadable(
                          l10n,
                          notLoadable,
                          state.unit,
                          locale: locale,
                        ),
                        style: AppTextStyles.rowDetail.copyWith(
                          color: context.appColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.l),
              if (bars.length > 1)
                AppSection(
                  header: l10n.plateBarWeight,
                  footer: l10n.plateBarFooter,
                  children: [
                    for (final bar in bars)
                      AppSelectableRow(
                        key: ValueKey('plate-bar-${bar.id}'),
                        title: _bar(bar, locale),
                        selected: bar.id == state.chosenBarId,
                        onPressed: () {
                          cubit.barChosen(bar.id);
                          unawaited(HapticFeedback.selectionClick());
                        },
                      ),
                  ],
                )
              else if (base != null)
                AppSection(
                  children: [
                    AppListRow(
                      title: bars.isEmpty
                          ? l10n.plateBase
                          : l10n.plateBarWeight,
                      accessory: AppListRowValue(weight(base)),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.l),
              AppSection(
                header: l10n.plateAvailableWeights,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.m),
                    child: Wrap(
                      spacing: AppSpacing.s,
                      runSpacing: AppSpacing.s,
                      children: [
                        for (final choice in state.plateChoices)
                          AppChip(
                            key: ValueKey('plate-${choice.weight}'),
                            label: weight(choice.weight),
                            selected: choice.isOn,
                            onPressed: () {
                              cubit.plateToggled(choice);
                              unawaited(HapticFeedback.selectionClick());
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppBottomCta(
          children: [
            AppCtaButton(
              label: l10n.keypadDone,
              onPressed: () {
                cubit.done();
                Navigator.of(context).pop(cubit.state.gym);
              },
            ),
          ],
        ),
      ],
    );
  }

  static String _bar(BarBaseWeight bar, String locale) =>
      '${TrackerText.amount(bar.baseWeight, locale: locale)} '
      '${TrackerText.unit(bar.unit)}';
}
