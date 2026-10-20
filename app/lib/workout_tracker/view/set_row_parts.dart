import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_tracker/logic/set_changes.dart';
import 'package:compound/workout_tracker/logic/tracker_clock.dart';
import 'package:compound/workout_tracker/view/set_table.dart';
import 'package:compound/workout_tracker/view/tick.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPicker;
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

/// The set's number with its kind's chip under it
/// (`SetTrackerRowView+SetType`). On a set of its own a tap opens the set
/// type menu, with Add Another Drop or Mini-Set where the set takes one; a
/// drop or mini-set is part of its set and only shows where it hangs from.
class SetBadge extends StatelessWidget {
  const new({
    required this.exercise,
    required this.set,
    required this.badge,
    required this.semanticsLabel,
    required this.actions,
    super.key,
  });

  final WorkoutExerciseModel exercise;
  final WorkoutSetModel set;
  final SetTableActions actions;
  final String badge;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    final rules = rulesSet(set);
    final chip = TrackerText.kindChip(l10n, set);
    final label = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          badge,
          style: AppTextStyles.rowDetail.semibold.copyWith(
            color: set.isWarmup ? colors.warmup : scheme.onSurface,
          ),
          semanticsLabel: semanticsLabel,
        ),
        if (chip != null)
          ExcludeSemantics(
            child: Text(
              chip,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.semibold.copyWith(
                color: rules.isSubSet ? colors.warmup : scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
    if (!r.ActiveWorkout.offersSetTypes(rules)) return label;
    final current = r.typeChoiceOf(rules);
    return PopupMenuButton<Object>(
      key: ValueKey('set-type-${set.id}'),
      tooltip: l10n.trackerSetType,
      padding: EdgeInsets.zero,
      onSelected: (value) => switch (value) {
        final r.SetTypeChoice choice => unawaited(_changeType(context, choice)),
        final r.SubSetKind kind => actions.addSubSet(set.id, kind),
        _ => null,
      },
      itemBuilder: (_) => [
        for (final choice in r.ActiveWorkout.setTypeOptions(rules))
          CheckedPopupMenuItem<Object>(
            value: choice,
            checked: choice == current,
            child: Text(TrackerText.setType(l10n, choice)),
          ),
        if (r.ActiveWorkout.offersDrop(rules))
          AppMenuItem<Object>(
            value: r.SubSetKind.drop,
            icon: AppSymbols.add,
            label: l10n.trackerAddDrop,
          ),
        if (r.ActiveWorkout.offersMiniSet(rules))
          AppMenuItem<Object>(
            value: r.SubSetKind.mini,
            icon: AppSymbols.add,
            label: l10n.trackerAddMiniSet,
          ),
      ],
      child: label,
    );
  }

  /// Sub-rows the new type has no use for go, asking first when any of
  /// them is logged (`onSetTypeSelected`).
  Future<void> _changeType(BuildContext context, r.SetTypeChoice choice) async {
    final l10n = context.l10n;
    if (r.typeChoiceOf(rulesSet(set)) == choice) return;
    final lost = exercise.loggedRowsLostBy(set.id, choice);
    if (lost > 0) {
      final change = await confirmDestructive(
        context,
        title: l10n.trackerChangeTypeTitle(
          TrackerText.setName(l10n, set, badge),
          TrackerText.setType(l10n, choice),
        ),
        message: l10n.trackerChangeTypeMessage(lost),
        action: l10n.trackerChange,
      );
      if (!change) return;
    }
    actions.setSetType(set.id, choice);
  }
}

/// Asks before something that cannot be undone, with [action] as the
/// destructive choice.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) => AppDialog.confirmDestructive(
  context,
  title: title,
  message: message,
  confirmLabel: action,
  cancelLabel: context.l10n.trackerCancel,
);

/// Deletes [set], asking first when its drops or mini-sets would go with
/// it: "Delete Set 2? This also deletes its 2 drop sets."
Future<void> deleteSet(
  BuildContext context,
  SetTableActions actions,
  WorkoutExerciseModel exercise,
  WorkoutSetModel set,
  String badge,
) async {
  final l10n = context.l10n;
  final message = TrackerText.subSetsDeleted(
    l10n,
    exercise.subSetsRemovedBy(set.id),
  );
  if (message != null) {
    final delete = await confirmDestructive(
      context,
      title: l10n.trackerDeleteSetTitle(TrackerText.setName(l10n, set, badge)),
      message: message,
      action: l10n.trackerDeleteSet,
    );
    if (!delete) return;
  }
  actions.deleteSet(set.id);
}

/// The rest picker (`SetRestSheet`): minutes and seconds wheels opening on
/// [initialSeconds]. Save returns the rest, `0` meaning none set by hand;
/// Close returns `null`.
Future<int?> showRestPicker(BuildContext context, int initialSeconds) =>
    showAppSheet<int>(
      context: context,
      builder: (_) => RestPickerSheet(initialSeconds: initialSeconds),
    );

class RestPickerSheet extends StatefulWidget {
  const new({required this.initialSeconds, super.key});

  final int initialSeconds;

  @override
  State<RestPickerSheet> createState() => _RestPickerSheetState();
}

class _RestPickerSheetState extends State<RestPickerSheet> {
  late int _minutes = (widget.initialSeconds ~/ 60).clamp(0, 59);
  late int _seconds = widget.initialSeconds % 60;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scale = MediaQuery.textScalerOf(context);
    Widget wheel({
      required Key key,
      required int selected,
      required String Function(String) label,
      required ValueChanged<int> onChanged,
    }) => Expanded(
      child: CupertinoPicker(
        key: key,
        itemExtent: scale.scale(36),
        scrollController: FixedExtentScrollController(initialItem: selected),
        onSelectedItemChanged: onChanged,
        children: [
          for (var value = 0; value < 60; value++)
            Center(child: Text(label(AppFormat.number(value)))),
        ],
      ),
    );
    return AppScaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppToolbarButton.close(
          semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
        title: Text(l10n.trackerSetRest),
        actions: [
          AppToolbarButton.confirm(
            key: const ValueKey('rest-save'),
            semanticLabel: l10n.trackerSave,
            onPressed: () =>
                Navigator.of(context).pop(_minutes * 60 + _seconds),
          ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: scale.scale(180),
            child: Row(
              children: [
                wheel(
                  key: const ValueKey('rest-minutes'),
                  selected: _minutes,
                  label: l10n.trackerRestMinutes,
                  onChanged: (value) => _minutes = value,
                ),
                wheel(
                  key: const ValueKey('rest-seconds'),
                  selected: _seconds,
                  label: l10n.trackerRestSeconds,
                  onChanged: (value) => _seconds = value,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A timed set's time field with a start/stop button beside it, as a
/// plank or a dead hang (`SetStopwatch`). While it runs the live clock
/// takes the field's place, a bar filling towards [targetSeconds]; a tap
/// stops it and writes the seconds held into the set. It never logs it.
class SetStopwatch extends StatefulWidget {
  const new({
    required this.setId,
    required this.targetSeconds,
    required this.field,
    required this.onStopped,
    super.key,
  });

  final String setId;

  /// Hears the seconds held when it is stopped.
  final ValueChanged<int> onStopped;

  /// The plan's seconds for a stretch or hold, else last time's.
  final int? targetSeconds;

  /// The time field, shown while the stopwatch is stopped.
  final Widget field;

  @override
  State<SetStopwatch> createState() => _SetStopwatchState();
}

class _SetStopwatchState extends State<SetStopwatch> {
  final _stopwatch = r.Stopwatch();

  DateTime _now() =>
      (context.read<TrackerClock?>() ?? const TrackerClock()).now();

  void _toggle() {
    if (_stopwatch.isRunning) {
      final seconds = _stopwatch.stop(_now());
      setState(() {});
      if (seconds == null) return;
      widget.onStopped(seconds);
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          AppFormat.duration(Duration(seconds: seconds)),
          Directionality.of(context),
        ),
      );
      return;
    }
    setState(() {
      _stopwatch
        ..targetSeconds = widget.targetSeconds
        ..start(_now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final running = _stopwatch.isRunning;
    final button = Semantics(
      button: true,
      label: running ? l10n.trackerStopTimer : l10n.trackerStartTimer,
      hint: running ? l10n.trackerStopTimerHint : null,
      excludeSemantics: true,
      child: Material(
        color: running ? scheme.primary : scheme.surfaceContainerHighest,
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.s)),
        ),
        child: InkWell(
          key: ValueKey('stopwatch-${widget.setId}'),
          customBorder: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.s)),
          ),
          onTap: _toggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppControlSize.row,
              minHeight: AppControlSize.row - 8,
            ),
            child: running
                ? Tick(
                    builder: (context, now) {
                      final elapsed = _stopwatch.elapsed(now);
                      final target = _stopwatch.targetSeconds;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppFormat.duration(Duration(seconds: elapsed)),
                              style: AppTextStyles.rowTitle.copyWith(
                                color: scheme.onPrimary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            if (target != null && target > 0)
                              LinearProgressIndicator(
                                value: (elapsed / target).clamp(0, 1),
                                color: scheme.onPrimary,
                                backgroundColor: scheme.onPrimary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  )
                : Icon(
                    AppSymbols.start,
                    size: AppIconSize.small.of(context),
                    color: scheme.primary,
                  ),
          ),
        ),
      ),
    );
    if (running) return button;
    return Row(
      spacing: AppSpacing.xs,
      children: [
        button,
        Expanded(child: widget.field),
      ],
    );
  }
}
