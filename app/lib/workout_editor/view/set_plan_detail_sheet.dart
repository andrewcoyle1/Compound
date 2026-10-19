import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_editor/cubit/set_plan_detail_cubit.dart';
import 'package:compound/workout_editor/logic/editor_text.dart';
import 'package:compound/workout_editor/view/editor_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Opens one set's plan as a sheet (Swift `SetPlanDetailView`); each change
/// goes straight to [onChange].
Future<void> showSetPlanDetail(
  BuildContext context, {
  required SetTarget target,
  required WorkoutSettings settings,
  required void Function(SetTarget) onChange,
}) {
  final analytics = context.read<AnalyticsRepository>();
  return showAppSheet<void>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) => SetPlanDetailCubit(
        target: target,
        onChange: onChange,
        analytics: analytics,
      ),
      child: const SetPlanDetailView(),
    ),
  );
}

class SetPlanDetailView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SetPlanDetailCubit>();
    final target = context.watch<SetPlanDetailCubit>().state;
    // A legacy failure set reads as AMRAP.
    final kind = WorkoutEditorRules.shownKind(target.setType);
    final text = EditorText(
      l10n,
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    void selection() => unawaited(HapticFeedback.selectionClick());
    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.editorSetNumber(target.setNumber)),
        actions: [
          AppToolbarButton.confirm(
            key: const Key('SetPlanDetail.done'),
            semanticLabel: l10n.editorDone,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            footer: l10n.editorSetPlanFooter,
            children: [
              ChoiceMenu<SetTargetSetType>(
                key: const Key('SetPlanDetail.kind'),
                tooltip: l10n.editorSetTypeLabel(target.setNumber),
                value: kind,
                choices: WorkoutEditorRules.kinds,
                title: text.kindTitle,
                onSelected: cubit.kindChanged,
                child: AppListRow(
                  title: l10n.editorSetType,
                  accessory: AppListRowMenu(text.kindTitle(kind)),
                ),
              ),
              if (kind == SetTargetSetType.drop) ...[
                CountStepper(
                  key: const Key('SetPlanDetail.drops'),
                  title: l10n.editorDrops(target.dropCount ?? 0),
                  value: target.dropCount ?? 0,
                  min: WorkoutEditorRules.dropCountRange.$1,
                  max: WorkoutEditorRules.dropCountRange.$2,
                  onChanged: cubit.dropCountChanged,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.l,
                    vertical: AppSpacing.s,
                  ),
                  child: Wrap(
                    spacing: AppSpacing.s,
                    runSpacing: AppSpacing.s,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(l10n.editorEachDrop, style: AppTextStyles.rowTitle),
                      for (final percent in WorkoutEditorRules.dropSteps)
                        AppChip(
                          label: text.dropStepTitle(percent),
                          selected: target.dropStep == percent,
                          onPressed: () {
                            if (target.dropStep != percent) selection();
                            cubit.dropStepPressed(percent);
                          },
                        ),
                    ],
                  ),
                ),
                AppNumberField(
                  key: const Key('SetPlanDetail.dropReps'),
                  value: target.dropReps?.toDouble(),
                  prompt: l10n.editorToFailureTitle,
                  label: l10n.editorRepsOnEachDrop,
                  onChanged: cubit.dropRepsChanged,
                ),
              ],
              if (WorkoutEditorRules.miniSetKinds.contains(kind))
                CountStepper(
                  key: const Key('SetPlanDetail.miniSets'),
                  title: l10n.editorMiniSets(target.miniSetCount ?? 0),
                  value: target.miniSetCount ?? 0,
                  min: WorkoutEditorRules.miniSetCountRange.$1,
                  max: WorkoutEditorRules.miniSetCountRange.$2,
                  onChanged: cubit.miniSetCountChanged,
                ),
              if (kind == SetTargetSetType.amrap)
                AppNumberField(
                  key: const Key('SetPlanDetail.amrapTarget'),
                  value: target.amrapTargetReps?.toDouble(),
                  prompt: l10n.editorOptional,
                  label: l10n.editorTargetReps,
                  onChanged: cubit.amrapTargetChanged,
                ),
              if (kind == SetTargetSetType.partials)
                ChoiceMenu<int?>(
                  key: const Key('SetPlanDetail.partials'),
                  tooltip: l10n.editorPartialReps,
                  value: target.partialReps,
                  choices: WorkoutEditorRules.partialRepsChoices(
                    target.partialReps,
                  ),
                  title: (reps) => reps == null
                      ? l10n.editorToFailureTitle
                      : l10n.repCount(reps),
                  onSelected: cubit.partialRepsChanged,
                  child: AppListRow(
                    title: l10n.editorPartialReps,
                    accessory: AppListRowMenu(
                      target.partialReps == null
                          ? l10n.editorToFailureTitle
                          : l10n.repCount(target.partialReps!),
                    ),
                  ),
                ),
              if (kind == SetTargetSetType.stretch ||
                  kind == SetTargetSetType.hold)
                ChoiceMenu<int>(
                  key: const Key('SetPlanDetail.hold'),
                  tooltip: l10n.editorDuration,
                  value:
                      target.holdSeconds ??
                      WorkoutEditorRules.defaultHoldSeconds,
                  choices: WorkoutEditorRules.holdChoices(
                    target.holdSeconds ?? WorkoutEditorRules.defaultHoldSeconds,
                  ),
                  title: l10n.editorSeconds,
                  onSelected: cubit.holdSecondsChanged,
                  child: AppListRow(
                    title: l10n.editorDuration,
                    accessory: AppListRowMenu(
                      l10n.editorSeconds(
                        target.holdSeconds ??
                            WorkoutEditorRules.defaultHoldSeconds,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
