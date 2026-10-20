import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/gym_profiles/view/gym_profile_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_tracker/cubit/equipment_sheet_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the equipment sheet on the exercise [setup] holds. [onChosen]
/// hears another variation chosen, and [onGymEdited] the gym saved after
/// its equipment was edited, each with the exercise's id.
Future<void> showEquipmentSheet(
  BuildContext context,
  EquipmentSheetSetup setup, {
  required void Function(String exerciseId, String variationId) onChosen,
  required void Function(String exerciseId, GymProfileModel gym) onGymEdited,
}) => showAppSheet<void>(
  context: context,
  builder: (context) => BlocProvider(
    create: (context) => EquipmentSheetCubit(
      setup,
      analytics: context.read<AnalyticsRepository>(),
    ),
    child: EquipmentSheetView(onChosen: onChosen, onGymEdited: onGymEdited),
  ),
);

/// An exercise's equipment variations (`WorkoutExerciseEquipmentSheetView`):
/// a tap on one applies it and closes; its ⋯ edits its equipment in the
/// workout's gym.
class EquipmentSheetView extends StatelessWidget {
  const new({required this.onChosen, required this.onGymEdited, super.key});

  final void Function(String exerciseId, String variationId) onChosen;
  final void Function(String exerciseId, GymProfileModel gym) onGymEdited;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<EquipmentSheetCubit>().state;
    return AppScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppToolbarButton.close(
          semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
        title: Text(state.exerciseName),
      ),
      body: state.hasNoVariations
          ? AppEmptyState(
              icon: AppSymbols.equipment,
              title: l10n.equipmentNone,
              description: l10n.equipmentNoVariations,
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                AppSection(
                  children: [
                    for (final item in state.items)
                      _VariationRow(
                        item: item,
                        onChosen: onChosen,
                        onGymEdited: onGymEdited,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _VariationRow extends StatelessWidget {
  const new({
    required this.item,
    required this.onChosen,
    required this.onGymEdited,
  });

  final VariationItem item;
  final void Function(String exerciseId, String variationId) onChosen;
  final void Function(String exerciseId, GymProfileModel gym) onGymEdited;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<EquipmentSheetCubit>();
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
                onChosen(exerciseId, item.id);
              }
              Navigator.of(context).pop();
            },
          ),
        ),
        if (canEdit)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
            child: AppIconButton(
              key: ValueKey('variation-edit-${item.id}'),
              icon: AppSymbols.more,
              semanticLabel: l10n.equipmentEdit(title),
              onPressed: () => unawaited(_edit(context, title)),
            ),
          ),
      ],
    );
  }

  /// The variation's equipment in the workout's gym; each save reaches the
  /// exercise, and "Not in this gym" follows it.
  Future<void> _edit(BuildContext context, String title) async {
    final cubit = context.read<EquipmentSheetCubit>();
    final gym = cubit.state.gym;
    if (gym == null) return;
    cubit.editPressed();
    await GymProfilePage.push(
      context,
      gym,
      scope: item.equipment,
      title: title,
      onSaved: (saved) {
        onGymEdited(cubit.state.exerciseId, saved);
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
