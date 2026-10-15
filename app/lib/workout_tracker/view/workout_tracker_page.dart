import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:compound/training_library/view/exercise_picker_page.dart';
import 'package:compound/workout_session_detail/view/workout_session_detail_page.dart';
import 'package:compound/workout_tracker/cubit/active_workout_cubit.dart';
import 'package:compound/workout_tracker/logic/set_keypad.dart';
import 'package:compound/workout_tracker/view/correction_bar.dart';
import 'package:compound/workout_tracker/view/exercise_card.dart';
import 'package:compound/workout_tracker/view/exercise_strip.dart';
import 'package:compound/workout_tracker/view/notes_sheet.dart';
import 'package:compound/workout_tracker/view/set_keypad_view.dart';
import 'package:compound/workout_tracker/view/tick.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:wakelock_plus/wakelock_plus.dart';

/// The workout under way (Swift `WorkoutTrackerView`), over the tabs: the
/// exercise strip, the card of the block it is on, and one button at the
/// foot that logs, skips the rest, moves on, finishes or resumes. The
/// workout carries on behind the tabs when it is minimised.
class WorkoutTrackerPage extends StatelessWidget {
  const new({this.opensKeypad = false, super.key});

  static const path = '/workout';
  static const name = 'workoutTracker';

  /// `?keypad=1`: the keypad opens on the next set's first field, for
  /// screenshots and a deep link straight to typing.
  static const keypadParameter = 'keypad';

  /// Opens the tracker over the tabs.
  static Future<void> show(BuildContext context) =>
      context.pushNamed<void>(name);

  final bool opensKeypad;

  @override
  Widget build(BuildContext context) =>
      WorkoutTrackerView(opensKeypad: opensKeypad);
}

class WorkoutTrackerView extends StatefulWidget {
  const new({this.opensKeypad = false, super.key});

  final bool opensKeypad;

  @override
  State<WorkoutTrackerView> createState() => _WorkoutTrackerViewState();
}

class _WorkoutTrackerViewState extends State<WorkoutTrackerView> {
  late final ActiveWorkoutCubit _cubit = context.read<ActiveWorkoutCubit>();
  late final AppLifecycleListener _lifecycle;
  bool _openedKeypad = false;

  @override
  void initState() {
    super.initState();
    _cubit
      ..appeared()
      ..checkStillTraining();
    // Kept awake only while the tracker is up, as the settings ask: once it
    // is minimised, finished or discarded, the phone may sleep.
    _keepAwake(enable: _cubit.state.settings?.keepAlive ?? true);
    // A change waiting to be kept is kept as the app leaves the screen; on
    // return, a workout left an hour asks whether it is still going.
    _lifecycle = AppLifecycleListener(
      onHide: _cubit.flush,
      onPause: _cubit.flush,
      onResume: _cubit.checkStillTraining,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _keepAwake(enable: false);
    _cubit.disappeared();
    super.dispose();
  }

  /// A screen that cannot be kept awake simply sleeps.
  static void _keepAwake({required bool enable}) =>
      unawaited(WakelockPlus.toggle(enable: enable).catchError((Object _) {}));

  void _maybeOpenKeypad(ActiveWorkoutState state) {
    if (!widget.opensKeypad || _openedKeypad) return;
    if (state.primaryAction case r.LogSetAction(:final setId)) {
      final set = state.set(setId);
      final exercise = state.exerciseHolding(setId);
      if (set == null || exercise == null) return;
      _openedKeypad = true;
      _cubit.openKeypad(setId, SetField.of(set, exercise.trackingMode).first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ActiveWorkoutCubit, ActiveWorkoutState>(
          listenWhen: (previous, current) =>
              current.effectId != previous.effectId,
          listener: _onEffect,
        ),
        BlocListener<ActiveWorkoutCubit, ActiveWorkoutState>(
          listenWhen: (previous, current) =>
              previous.finishedSession == null &&
              current.finishedSession != null,
          listener: (context, state) {
            final session = state.finishedSession!;
            unawaited(HapticFeedback.successNotification());
            _cubit.summaryShown();
            context.pushReplacementNamed(
              WorkoutSessionDetailPage.summaryName,
              pathParameters: {
                WorkoutSessionDetailPage.sessionIdParameter: session.id,
              },
              extra: session,
            );
          },
        ),
      ],
      // Keeps the last workout on screen while the summary replaces it.
      child: BlocBuilder<ActiveWorkoutCubit, ActiveWorkoutState>(
        buildWhen: (previous, current) =>
            current.isActive || current.finishedSession == null,
        builder: (context, state) {
          if (state.isActive) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _maybeOpenKeypad(state),
            );
            return _Tracker(state: state);
          }
          return _NoWorkout(
            isLoading: state.status == ActiveWorkoutStatus.loading,
          );
        },
      ),
    );
  }

  void _onEffect(BuildContext context, ActiveWorkoutState state) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    void announce(String message) => unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
    );
    switch (state.effect) {
      case SetLoggedEffect(:final setId, :final allComplete):
        unawaited(HapticFeedback.successNotification());
        final set = state.set(setId);
        final exercise = state.exerciseHolding(setId);
        if (set != null && exercise != null) {
          announce(TrackerText.logged(l10n, set, exercise, locale: locale));
        }
        if (allComplete) announce(l10n.trackerAllComplete);
      case LogRefusedEffect(:final problem):
        unawaited(HapticFeedback.errorNotification());
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.trackerLogRefusedTitle),
            content: Text(TrackerText.problem(l10n, problem)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.keypadDone),
              ),
            ],
          ),
        );
      case SetDeletedEffect():
        unawaited(HapticFeedback.successNotification());
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.trackerSetDeleted),
              action: SnackBarAction(
                label: l10n.trackerUndo,
                onPressed: _cubit.undo,
              ),
            ),
          );
      case SelectionEffect():
        unawaited(HapticFeedback.selectionClick());
      case SavedEffect():
        unawaited(HapticFeedback.successNotification());
      case RestOverEffect():
        // The rest-complete haptic, apart from a logged set's. Flutter has
        // no mobile alert sound, so the in-app sound waits for an audio
        // slice.
        if (state.settings?.restTimerVibrate ?? true) {
          unawaited(HapticFeedback.warningNotification());
        }
      case StillTrainingEffect(:final lastSet):
        unawaited(_askStillTraining(context, lastSet));
      case StartFailedEffect() || null:
        break;
    }
  }

  /// "Still training?": Finish as of the last set, so the forgotten hour is
  /// not counted, or Keep Going.
  Future<void> _askStillTraining(BuildContext context, DateTime lastSet) async {
    final l10n = context.l10n;
    final time = TimeOfDay.fromDateTime(lastSet).format(context);
    final finish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.notifIdleTitle),
        content: Text(l10n.notifIdleBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.trackerKeepGoing),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.trackerFinishAt(time)),
          ),
        ],
      ),
    );
    if (finish != true || !context.mounted) return;
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    await _cubit.finish(
      firstWeekday: firstDay == 0 ? DateTime.sunday : firstDay,
      at: lastSet,
    );
  }
}

/// Leaves the tracker: back to what was under it, else Today.
void closeTracker(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppTab.today.path);
  }
}

class _NoWorkout extends StatelessWidget {
  const new({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.trackerMinimize,
          onPressed: () => closeTracker(context),
          icon: const Icon(AppSymbols.minimize),
        ),
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator.adaptive()
            : _Unavailable(
                icon: AppSymbols.workout,
                title: l10n.trackerNoWorkoutTitle,
                message: l10n.trackerNoWorkoutMessage,
              ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.s,
        children: [
          Icon(
            icon,
            size: AppIconSize.large.of(context),
            color: scheme.onSurfaceVariant,
          ),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.rowDetail.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _Tracker extends StatelessWidget {
  const new({required this.state});

  final ActiveWorkoutState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ActiveWorkoutCubit>();
    final session = state.session!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.trackerMinimize,
          onPressed: () {
            cubit.minimized();
            closeTracker(context);
          },
          icon: const Icon(AppSymbols.minimize),
        ),
        title: _Title(state: state),
        actions: [_Menu(state: state)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (session.exercises.isNotEmpty)
            ExerciseStrip(
              items: state.strip,
              onSelected: cubit.selectExercise,
              onAddExercise: () => unawaited(_addExercises(context)),
            ),
          Expanded(
            child: session.exercises.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: _Unavailable(
                        icon: AppSymbols.exercise,
                        title: l10n.trackerNoExercisesTitle,
                        message: l10n.trackerNoExercisesMessage,
                        action: FilledButton.icon(
                          onPressed: () => unawaited(_addExercises(context)),
                          icon: const Icon(AppSymbols.add),
                          label: Text(l10n.trackerAddExercise),
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.l,
                      0,
                      AppSpacing.l,
                      AppSpacing.l,
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    children: [ExerciseCard(state: state)],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _Foot(state: state),
    );
  }
}

/// Adds the exercises picked, after the last.
Future<void> _addExercises(BuildContext context) async {
  final cubit = context.read<ActiveWorkoutCubit>()..closeKeypad();
  final picked = await ExercisePickerPage.show(context);
  if (picked != null) cubit.addExercises(picked);
}

/// The workout's name over its date and running clock; paused time is left
/// out, and while paused the clock gives way to Paused.
class _Title extends StatelessWidget {
  const new({required this.state});

  final ActiveWorkoutState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final session = state.session!;
    return Tick(
      builder: (context, now) {
        final clock = state.isPaused
            ? l10n.trackerPaused
            : AppFormat.duration(state.elapsedAt(now));
        final date = DateFormat.MMMEd(locale)
            .format(session.dateCreated.toLocal());
        return MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.rowTitle.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$date · $clock',
                style: AppTextStyles.label.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _MenuAction { pause, finish, notes, discard }

class _Menu extends StatelessWidget {
  const new({required this.state});

  final ActiveWorkoutState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final danger = context.appColors.danger;
    return PopupMenuButton<_MenuAction>(
      tooltip: l10n.trackerOptions,
      icon: Icon(AppSymbols.more),
      onSelected: (action) => switch (action) {
        _MenuAction.pause => context.read<ActiveWorkoutCubit>().togglePause(),
        _MenuAction.finish => unawaited(finishWorkout(context)),
        _MenuAction.notes => unawaited(_workoutNotes(context)),
        _MenuAction.discard => unawaited(_discard(context)),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _MenuAction.pause,
          child: ListTile(
            leading: Icon(state.isPaused ? AppSymbols.start : AppSymbols.pause),
            title: Text(
              state.isPaused ? l10n.trackerResume : l10n.trackerPause,
            ),
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.finish,
          child: ListTile(
            leading: const Icon(AppSymbols.selected),
            title: Text(l10n.trackerFinishMenu),
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.notes,
          child: ListTile(
            leading: const Icon(AppSymbols.note),
            title: Text(l10n.trackerNotesMenu),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.discard,
          child: ListTile(
            leading: Icon(AppSymbols.delete, color: danger),
            title: Text(l10n.trackerDiscard, style: TextStyle(color: danger)),
          ),
        ),
      ],
    );
  }

  Future<void> _workoutNotes(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<ActiveWorkoutCubit>();
    final notes = await showNotesSheet(
      context,
      title: l10n.trackerWorkoutNotesTitle,
      saveLabel: l10n.trackerSave,
      fields: [
        NoteField(
          label: l10n.trackerSessionNote,
          initial: state.session?.notes ?? '',
        ),
      ],
    );
    if (notes != null) cubit.setWorkoutNotes(notes.single);
  }

  Future<void> _discard(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<ActiveWorkoutCubit>()..discardPressed();
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trackerDiscardTitle),
        content: Text(l10n.trackerDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.trackerCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.danger,
            ),
            child: Text(l10n.trackerDiscardConfirm),
          ),
        ],
      ),
    );
    if (!(discard ?? false)) return;
    await cubit.discard();
    if (context.mounted) closeTracker(context);
  }
}

enum _NoSetsChoice { discard, save }

/// Finishing: the notes sheet confirms it; a workout with nothing logged
/// is asked about first (`WorkoutTrackerPresenter+Finish`).
Future<void> finishWorkout(BuildContext context) async {
  final l10n = context.l10n;
  final cubit = context.read<ActiveWorkoutCubit>()
    ..closeKeypad()
    ..finishPressed();
  final notes = await showNotesSheet(
    context,
    title: l10n.trackerFinishTitle,
    saveLabel: l10n.trackerFinish,
    fields: [
      NoteField(
        label: l10n.trackerSessionNote,
        footer: l10n.trackerSessionNoteFooter,
        initial: cubit.state.session?.notes ?? '',
      ),
    ],
  );
  if (notes == null || !context.mounted) return;
  cubit.setWorkoutNotes(notes.single);
  if (!cubit.state.hasLoggedSet) {
    final choice = await showDialog<_NoSetsChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trackerNoSetsTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.trackerCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_NoSetsChoice.discard),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.danger,
            ),
            child: Text(l10n.trackerDiscard),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_NoSetsChoice.save),
            child: Text(l10n.trackerSaveAnyway),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case _NoSetsChoice.discard:
        await cubit.discard();
        if (context.mounted) closeTracker(context);
        return;
      case _NoSetsChoice.save:
        break;
      case null:
        return;
    }
  }
  if (!context.mounted) return;
  // The locale's first day of the week (0 = Sunday), as Today counts.
  final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
  await cubit.finish(firstWeekday: firstDay == 0 ? DateTime.sunday : firstDay);
}

/// The foot of the screen: the set just logged while its rest runs, the
/// button, and the keypad under them.
class _Foot extends StatelessWidget {
  const new({required this.state});

  final ActiveWorkoutState state;

  @override
  Widget build(BuildContext context) {
    final keypad = state.keypad;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Tick(
          builder: (context, now) {
            final slot = state.slotAt(now);
            final correction = state.correction;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (slot is r.SlotSkipRest && correction != null)
                  CorrectionBar(state: state, correction: correction),
                if (slot != null)
                  _PrimaryButton(state: state, slot: slot, now: now),
                if (keypad != null) SetKeypadView(state: state, keypad: keypad),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One button for every action, with +15s beside it while resting.
class _PrimaryButton extends StatelessWidget {
  const new({required this.state, required this.slot, required this.now});

  final ActiveWorkoutState state;
  final r.SlotAction slot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final cubit = context.read<ActiveWorkoutCubit>();
    // At large text sizes the figures give way: the row above shows them.
    final isLarge = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final inGrace = state.isInGraceAt(now);
    String title;
    switch (slot) {
      case r.SlotLog(:final setId):
        final set = state.set(setId);
        final exercise = state.exerciseHolding(setId);
        title = set == null || exercise == null
            ? ''
            : TrackerText.logTitle(l10n, set, exercise, locale: locale);
        if (isLarge) title = title.split(' · ').first;
        if (inGrace) title = l10n.trackerRestDone(title);
      case r.SlotNext(:final exerciseId):
        title = l10n.trackerNext(state.exercise(exerciseId)?.name ?? '');
      case r.SlotFinish():
        title = l10n.trackerFinishTitle;
      case r.SlotResume():
        title = l10n.trackerResume;
      case r.SlotSkipRest():
        final left = state.restEnd!.difference(now);
        final clock = AppFormat.duration(
          left + const Duration(milliseconds: 999),
        );
        title = isLarge
            ? l10n.trackerSkipRest
            : '${l10n.trackerSkipRest} $clock';
    }
    final button = AppCtaButton(
      label: title,
      onPressed: inGrace
          ? null
          : slot is r.SlotFinish
          ? () => unawaited(finishWorkout(context))
          : cubit.pressPrimary,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: slot is r.SlotSkipRest
          ? Row(
              spacing: AppSpacing.s,
              children: [
                Expanded(child: button),
                Expanded(
                  child: Semantics(
                    label: l10n.trackerAddRestSpoken,
                    button: true,
                    excludeSemantics: true,
                    onTap: cubit.addRestTime,
                    child: AppCtaButton(
                      label: l10n.trackerAddRestShort,
                      variant: AppCtaVariant.secondary,
                      onPressed: cubit.addRestTime,
                    ),
                  ),
                ),
              ],
            )
          : button,
    );
  }
}
