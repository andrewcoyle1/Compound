import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/programs/view/mesocycle_style.dart';
import 'package:compound/training_library/logic/template_summary.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/training_library/view/library_widgets.dart'
    show MuscleChips;
import 'package:compound_models/compound_models.dart';
import 'package:program_repository/program_repository.dart';

/// The workouts in one microcycle: its day plans with exercises.
int workoutCount(Mesocycle mesocycle) =>
    mesocycle.workoutTemplates.where((day) => day.exercises.isNotEmpty).length;

/// "Hypertrophy Phase", "Strength Phase", "Power Phase".
String phaseLabel(AppLocalizations l10n, PeriodisationPhase phase) =>
    switch (phase) {
      PeriodisationPhase.hypertrophy => l10n.programPhaseHypertrophy,
      PeriodisationPhase.strength => l10n.programPhaseStrength,
      PeriodisationPhase.power => l10n.programPhasePower,
    };

/// Where the deload falls: "None", "First Cycle", "Last Cycle".
String deloadTitle(AppLocalizations l10n, DeloadType deload) =>
    switch (deload) {
      DeloadType.none => l10n.none,
      DeloadType.start => l10n.programDeloadFirst,
      DeloadType.end => l10n.programDeloadLast,
    };

/// A mesocycle's badge in its colour, its name and how many workouts a
/// microcycle holds, with the deload and phase chips when they apply
/// (Swift `MesocycleHeader`). The badge draws the glyph its SF Symbol is
/// mapped to ([mesocycleGlyph]), or the mesocycle glyph.
class const MesocycleHeader({
  required final Mesocycle mesocycle,
  final bool isDeload = false,
  final PeriodisationPhase? phase,
  final Widget? trailing,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colour = AppColors.fromHex(mesocycle.colour) ?? scheme.primary;
    final side = MediaQuery.textScalerOf(context).scale(AppControlSize.row);
    final phase = this.phase;
    final trailing = this.trailing;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.s,
        ),
        child: Row(
          spacing: AppSpacing.m,
          children: [
            ExcludeSemantics(
              child: SizedBox.square(
                dimension: side,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.tintedSurface(colour),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(mesocycleGlyph(mesocycle.icon), color: colour),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xxs,
                children: [
                  Text(
                    mesocycle.name,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (isDeload)
                        AppChip(
                          label: l10n.programDeloadWeek,
                          tint: scheme.onSurfaceVariant,
                        ),
                      if (phase != null)
                        AppChip(
                          label: phaseLabel(l10n, phase),
                          tint: scheme.onSurfaceVariant,
                        ),
                      Text(
                        l10n.workoutsCount(workoutCount(mesocycle)),
                        style: AppTextStyles.label.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// A day plan's row: its name, its exercises or "Rest", and the muscles
/// they work (Swift `WorkoutTemplateRow`).
class const DayPlanRow({
  required final WorkoutTemplateModel plan,
  final Widget? leading,
  final Widget? trailing,
  final String? badge,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final names = [for (final e in plan.exercises) e.exercise.name].join(', ');
    final badge = this.badge;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.m,
      ),
      child: Row(
        spacing: AppSpacing.m,
        children: [
          ?leading,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Wrap(
                  spacing: AppSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      plan.name,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    if (badge != null) AppChip(label: badge),
                  ],
                ),
                Text(
                  plan.exercises.isEmpty ? l10n.programRest : names,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.rowDetail.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (plan.exercises.isNotEmpty)
                  MuscleChips(
                    TemplateSummary.muscleTags(plan, l10n.muscleName),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Asks before a destructive change; true once confirmed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
}) => AppDialog.confirmDestructive(
  context,
  title: title,
  confirmLabel: confirmLabel,
  message: message,
);

/// Runs one of [ProgramsCubit]'s actions and answers whether it worked.
extension ProgramActionResult on ProgramsCubit {
  /// [action] run on this cubit; true once it has succeeded.
  Future<bool> succeeded(Future<void> Function(ProgramsCubit) action) async {
    final before = state.actionId;
    await action(this);
    return state.actionId != before && state.actionSucceeded;
  }
}
