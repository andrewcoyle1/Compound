import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/training/logic/workout_settings_rules.dart';
import 'package:compound/settings/training/view/timer_duration_page.dart';
import 'package:compound/settings/training/view/workout_settings_screen.dart';
import 'package:compound_models/compound_models.dart';
import 'package:go_router/go_router.dart';

/// Rest Timer (Swift `RestTimerSettingsView`): when rests run, how they
/// end, how they scale, and, with Set Plan on, the rests within a set and
/// the AMRAP rule.
class RestTimerSettingsPage extends StatelessWidget {
  const new({super.key});

  /// Relative to its parent route (`settings_routes.dart`).
  static const path = 'rest-timer';
  static const name = 'settingsRestTimer';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return WorkoutSettingsScreen(
      screen: 'RestTimerSettingsView',
      title: l10n.workoutSettingsRestTimer,
      sections: (context, settings, change) {
        final locale = Localizations.localeOf(context).toLanguageTag();
        AppListRowToggle toggle(
          String title,
          String subtitle,
          String key, {
          required bool value,
          IconData? icon,
        }) => AppListRowToggle(
          title: title,
          subtitle: subtitle,
          icon: icon,
          value: value,
          onChanged: (value) => change({key: value}),
        );
        return [
          AppSection(
            header: l10n.restTimerBehaviorHeader,
            children: [
              toggle(
                l10n.restTimerUseRestTimers,
                l10n.restTimerUseRestTimersSubtitle,
                WorkoutSettingsKeys.useRestTimers,
                value: settings.useRestTimers,
                icon: AppSymbols.rest,
              ),
              AppListRowButton(
                title: l10n.restTimerDuration,
                subtitle: l10n.restTimerDurationSubtitle,
                icon: AppSymbols.duration,
                onPressed: () => context.pushNamed(TimerDurationPage.name),
              ),
              toggle(
                l10n.restTimerAfterLastWarmUp,
                l10n.restTimerAfterLastWarmUpSubtitle,
                WorkoutSettingsKeys.restAfterLastWarmUp,
                value: settings.restAfterLastWarmUp,
                icon: AppSymbols.warmup,
              ),
              toggle(
                l10n.restTimerBetweenExercises,
                l10n.restTimerBetweenExercisesSubtitle,
                WorkoutSettingsKeys.restBetweenExercises,
                value: settings.restBetweenExercises,
              ),
              toggle(
                l10n.restTimerBetweenSides,
                l10n.restTimerBetweenSidesSubtitle,
                WorkoutSettingsKeys.restBetweenSideSets,
                value: settings.restBetweenSideSets,
                icon: AppSymbols.splitSides,
              ),
            ],
          ),
          AppSection(
            header: l10n.restTimerNotificationsHeader,
            children: [
              toggle(
                l10n.restTimerPlaySound,
                l10n.restTimerPlaySoundSubtitle,
                WorkoutSettingsKeys.restTimerPlaySound,
                value: settings.restTimerPlaySound,
              ),
              toggle(
                l10n.restTimerVibrate,
                l10n.restTimerVibrateSubtitle,
                WorkoutSettingsKeys.restTimerVibrate,
                value: settings.restTimerVibrate,
              ),
            ],
          ),
          AppSection(
            header: l10n.restTimerScalingHeader,
            children: [
              for (final scaling in RestScaling.values)
                SettingsMenuRow<double>(
                  title: switch (scaling) {
                    RestScaling.warmUp => l10n.restTimerScalingWarmUp,
                    RestScaling.betweenExercises =>
                      l10n.restTimerScalingBetweenExercises,
                    RestScaling.sideSets => l10n.restTimerScalingSides,
                  },
                  value: scaling.of(settings),
                  options: [
                    for (final option in RestScaling.options)
                      (option, AppFormat.percent(option, locale: locale)),
                  ],
                  onChanged: (value) => change({scaling.key: value}),
                ),
            ],
          ),
          if (settings.plansSets) ...[
            AppSection(
              header: l10n.restTimerWithinSetHeader,
              footer: l10n.restTimerWithinSetFooter,
              children: [
                AppListRow(
                  title: l10n.restTimerDropSet,
                  subtitle: l10n.restTimerDropSetSubtitle,
                  accessory: AppListRowValue(l10n.restTimerNone),
                ),
                for (final kind in IntraSetKind.values)
                  _IntraSetRestRow(
                    kind: kind,
                    selected: settings.intraSetRest(kind),
                    onSelected: (seconds) => change({kind.key: seconds}),
                  ),
              ],
            ),
            _AmrapSection(settings: settings, change: change),
          ],
        ];
      },
    );
  }
}

class _IntraSetRestRow extends StatelessWidget {
  const new({
    required this.kind,
    required this.selected,
    required this.onSelected,
  });

  final IntraSetKind kind;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = switch (kind) {
      IntraSetKind.myo => l10n.restTimerMyo,
      IntraSetKind.restPause => l10n.restTimerRestPause,
      IntraSetKind.cluster => l10n.restTimerCluster,
    };
    return AppListRow(
      title: title,
      subtitle: switch (kind) {
        IntraSetKind.myo => l10n.restTimerMyoSubtitle,
        IntraSetKind.restPause => l10n.restTimerRestPauseSubtitle,
        IntraSetKind.cluster => l10n.restTimerClusterSubtitle,
      },
      accessory: AppListRowCustom(
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final seconds in kind.options)
              Semantics(
                label: '$title, ${l10n.workoutSettingsSeconds(seconds)}',
                excludeSemantics: true,
                button: true,
                selected: seconds == selected,
                child: AppChip(
                  label: l10n.workoutSettingsSeconds(seconds),
                  selected: seconds == selected,
                  onPressed: () {
                    // Choosing the rest already chosen saves nothing.
                    if (seconds != selected) onSelected(seconds);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AmrapSection extends StatelessWidget {
  const new({required this.settings, required this.change});

  final WorkoutSettings settings;
  final WorkoutSettingsChange change;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final raises = settings.raisesAmrapTarget;
    final addsWeight = settings.addsWeightAtAmrapTarget;
    final ceiling = settings.amrapWeightCeiling;
    void setCeiling(int target) => change(amrapCeilingChange(target));
    return AppSection(
      header: l10n.restTimerFailureSetsHeader,
      children: [
        AppListRowToggle(
          title: l10n.restTimerRaiseTarget,
          subtitle: l10n.restTimerRaiseTargetSubtitle,
          icon: AppSymbols.doNext,
          value: raises,
          onChanged: (value) =>
              change({WorkoutSettingsKeys.amrapRaisesTarget: value}),
        ),
        // Without raising the target there is no ceiling to reach.
        AppListRowToggle(
          title: l10n.restTimerAddWeight,
          subtitle: addsWeight
              ? l10n.restTimerAddWeightAt(ceiling)
              : l10n.restTimerAddWeightOff,
          icon: AppSymbols.add,
          value: addsWeight,
          onChanged: raises
              ? (value) => change({WorkoutSettingsKeys.amrapAddsWeight: value})
              : null,
        ),
        if (addsWeight)
          Semantics(
            label: l10n.restTimerCeilingLabel,
            value: '$ceiling',
            increasedValue: '${ceiling + 1}',
            decreasedValue: '${ceiling - 1}',
            onIncrease: raises && ceiling < amrapCeilingRange.max
                ? () => setCeiling(ceiling + 1)
                : null,
            onDecrease: raises && ceiling > amrapCeilingRange.min
                ? () => setCeiling(ceiling - 1)
                : null,
            child: ExcludeSemantics(
              child: AppListRow(
                title: l10n.restTimerCeiling(ceiling),
                accessory: AppListRowCustom(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.s,
                    children: [
                      AppIconButton(
                        icon: AppSymbols.decrease,
                        semanticLabel: l10n.editorDecrease,
                        onPressed: raises && ceiling > amrapCeilingRange.min
                            ? () => setCeiling(ceiling - 1)
                            : null,
                      ),
                      AppIconButton(
                        icon: AppSymbols.add,
                        semanticLabel: l10n.editorIncrease,
                        onPressed: raises && ceiling < amrapCeilingRange.max
                            ? () => setCeiling(ceiling + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
