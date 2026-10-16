import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/gym_profiles/view/gym_profile_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_tracker/cubit/active_workout_cubit.dart';
import 'package:compound/workout_tracker/cubit/equipment_sheet_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the equipment sheet on the exercise [setup] holds.
Future<void> showEquipmentSheet(
  BuildContext context,
  EquipmentSheetSetup setup,
) {
  final tracker = context.read<ActiveWorkoutCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: tracker),
        BlocProvider(
          create: (context) => EquipmentSheetCubit(
            setup,
            analytics: context.read<AnalyticsRepository>(),
          ),
        ),
      ],
      child: const EquipmentSheetView(),
    ),
  );
}

/// An exercise's equipment variations (`WorkoutExerciseEquipmentSheetView`):
/// a tap on one applies it and closes; its ⋯ edits its equipment in the
/// workout's gym.
class EquipmentSheetView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<EquipmentSheetCubit>().state;
    final scheme = Theme.of(context).colorScheme;
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
                child: Semantics(
                  header: true,
                  child: Text(
                    state.exerciseName,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.rowTitle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppControlSize.row),
            ],
          ),
        ),
        if (state.hasNoVariations)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              spacing: AppSpacing.s,
              children: [
                Icon(
                  AppSymbols.equipment,
                  size: AppIconSize.large.of(context),
                  color: scheme.onSurfaceVariant,
                ),
                Text(l10n.equipmentNone, style: AppTextStyles.sectionTitle),
                Text(
                  l10n.equipmentNoVariations,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.rowDetail.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                AppSection(
                  children: [
                    for (final item in state.items) _VariationRow(item: item),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VariationRow extends StatelessWidget {
  const new({required this.item});

  final VariationItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<EquipmentSheetCubit>();
    final tracker = context.read<ActiveWorkoutCubit>();
    final title = l10n.equipmentVariation(AppFormat.number(item.number));
    final (selected, exerciseId, canEdit) = context
        .select<EquipmentSheetCubit, (bool, String, bool)>(
          (cubit) => (
            cubit.state.chosenId == item.id,
            cubit.state.exerciseId,
            cubit.state.gym != null,
          ),
        );
    return Row(
      children: [
        Expanded(
          child: AppSelectableRow(
            key: ValueKey('variation-${item.id}'),
            title: title,
            subtitle: _detail(l10n, item),
            selected: selected,
            onPressed: () {
              // Tapping the one already chosen only closes.
              if (!selected) {
                cubit.selected(item.id);
                tracker.chooseVariation(exerciseId, item.id);
              }
              Navigator.of(context).pop();
            },
          ),
        ),
        if (canEdit)
          IconButton(
            key: ValueKey('variation-edit-${item.id}'),
            tooltip: l10n.equipmentEdit(title),
            icon: Icon(AppSymbols.more),
            onPressed: () => unawaited(_edit(context, title)),
          ),
      ],
    );
  }

  /// The variation's equipment in the workout's gym; each save reaches the
  /// exercise, and "Not in this gym" follows it.
  Future<void> _edit(BuildContext context, String title) async {
    final cubit = context.read<EquipmentSheetCubit>();
    final tracker = context.read<ActiveWorkoutCubit>();
    final gym = cubit.state.gym;
    if (gym == null) return;
    cubit.editPressed();
    await GymProfilePage.push(
      context,
      gym,
      scope: item.equipment,
      title: title,
      onSaved: (saved) {
        tracker.gymEdited(cubit.state.exerciseId, saved);
        if (!cubit.isClosed) cubit.gymSaved(saved);
      },
    );
  }

  /// What it loads with and what braces it, leaving out either it lacks,
  /// and whether the gym has it all.
  static String? _detail(AppLocalizations l10n, VariationItem item) {
    String? names(List<String?> names) => names.isEmpty
        ? null
        : [for (final name in names) name ?? l10n.removedEquipment].join(', ');
    final parts = [
      if (names(item.resistance) case final names?)
        l10n.equipmentResistance(names),
      if (names(item.support) case final names?) l10n.equipmentSupport(names),
      if (!item.isAvailable) l10n.equipmentNotInGym,
    ];
    return parts.isEmpty ? null : parts.join('\n');
  }
}
