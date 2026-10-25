import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/gym_profiles/view/gym_profile_page.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/training/view/workout_settings_page.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:compound/tips/feature_tips.dart';
import 'package:compound/training_library/view/exercise_picker_page.dart';
import 'package:compound/workout_session_detail/view/workout_session_detail_page.dart';
import 'package:compound/workout_tracker/cubit/active_workout_cubit.dart';
import 'package:compound/workout_tracker/logic/set_keypad.dart';
import 'package:compound/workout_tracker/view/correction_bar.dart';
import 'package:compound/workout_tracker/view/exercise_card.dart';
import 'package:compound/workout_tracker/view/exercise_strip.dart';
import 'package:compound/workout_tracker/view/notes_sheet.dart';
import 'package:compound/workout_tracker/view/rest_sound.dart';
import 'package:compound/workout_tracker/view/set_keypad_view.dart';
import 'package:compound/workout_tracker/view/tick.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
            // The summary's hero plays the success haptic as its count
            // lands, so the finish is felt once.
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
        unawaited(AppHaptics.success());
        final set = state.set(setId);
        final exercise = state.exerciseHolding(setId);
        if (set != null && exercise != null) {
          announce(TrackerText.logged(l10n, set, exercise, locale: locale));
        }
        if (allComplete) announce(l10n.trackerAllComplete);
      case LogRefusedEffect(:final problem):
        unawaited(AppHaptics.error());
        unawaited(
          showAppDialog<void>(
            context: context,
            title: l10n.trackerLogRefusedTitle,
            message: TrackerText.problem(l10n, problem),
            actions: [AppDialogAction(label: l10n.keypadDone)],
          ),
        );
      case SetDeletedEffect():
        unawaited(AppHaptics.success());
        showAppSnackBar(
          context,
          l10n.trackerSetDeleted,
          action: AppSnackBarAction(
            label: l10n.trackerUndo,
            onPressed: _cubit.undo,
          ),
        );
      case SelectionEffect():
        unawaited(AppHaptics.selection());
      case SavedEffect():
        unawaited(AppHaptics.success());
      case RestOverEffect():
        // Sound and vibration asked for separately
        // (`announceRestCompletion`); the warning haptic, apart from a
        // logged set's success.
        if (state.settings?.restTimerPlaySound ?? true) {
          unawaited(RestSound.play());
        }
        if (state.settings?.restTimerVibrate ?? true) {
          unawaited(AppHaptics.warning());
        }
      case GymSaveFailedEffect():
        unawaited(AppHaptics.error());
        unawaited(
          showAppDialog<void>(
            context: context,
            title: l10n.trackerUnableToSaveGym,
            message: l10n.gymCheckConnection,
            actions: [AppDialogAction(label: l10n.keypadDone)],
          ),
        );
      case BlockMovedEffect(:final position, :final count):
        unawaited(AppHaptics.selection());
        announce(l10n.trackerPosition(position, count));
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
    final finish = await showAppDialog<bool>(
      context: context,
      title: l10n.notifIdleTitle,
      message: l10n.notifIdleBody,
      actions: [
        AppDialogAction(
          label: l10n.trackerKeepGoing,
          value: false,
          role: AppDialogRole.cancel,
        ),
        AppDialogAction(label: l10n.trackerFinishAt(time), value: true),
      ],
    );
    if (finish != true || !context.mounted) return;
    final firstDay = firstDayOfWeekIndex(context);
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
    return AppScaffold(
      appBar: AppBar(
        leading: AppToolbarButton(
          icon: AppSymbols.minimize,
          semanticLabel: l10n.trackerMinimize,
          onPressed: () => closeTracker(context),
        ),
      ),
      body: isLoading
          ? AppLoadingView(label: l10n.launchLoading)
          : AppEmptyState(
              icon: AppSymbols.workout,
              title: l10n.trackerNoWorkoutTitle,
              description: l10n.trackerNoWorkoutMessage,
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
    return ScreenTips(
      screen: 'WorkoutTrackerView',
      tips: const [FeatureTips.setSwipe, FeatureTips.setFillLast],
      child: AppScaffold(
        appBar: AppBar(
          leading: AppToolbarButton(
            icon: AppSymbols.minimize,
            semanticLabel: l10n.trackerMinimize,
            onPressed: () {
              cubit.minimized();
              closeTracker(context);
            },
          ),
          title: _Title(state: state),
          // On a tablet the bar has room for the workout's controls, which
          // leave the menu (`WorkoutTrackerView+Toolbar`).
          actions: [
            if (context.isRegularWidth) ...[
              AppToolbarButton(
                icon: state.isPaused ? AppSymbols.start : AppSymbols.pause,
                semanticLabel: state.isPaused
                    ? l10n.trackerResume
                    : l10n.trackerPause,
                onPressed: cubit.togglePause,
              ),
              AppToolbarButton(
                icon: AppSymbols.selected,
                semanticLabel: l10n.trackerFinishMenu,
                onPressed: () => unawaited(finishWorkout(context)),
              ),
              AppToolbarButton(
                icon: AppSymbols.note,
                semanticLabel: l10n.trackerNotesMenu,
                onPressed: () => unawaited(_workoutNotes(context, state)),
              ),
            ],
            _Menu(state: state, compact: !context.isRegularWidth),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (session.exercises.isNotEmpty)
              ExerciseStrip(
                items: state.strip,
                onSelected: cubit.selectExercise,
                onAddExercise: () => unawaited(_addExercises(context)),
                onDoNext: cubit.doNext,
                onDoLater: cubit.doLater,
                onMove: cubit.moveBlock,
              ),
            // Out of the way while typing into a set.
            if (session.exercises.isNotEmpty && state.keypad == null)
              _Now(state: state),
            Expanded(
              child: session.exercises.isEmpty
                  ? AppEmptyState(
                      icon: AppSymbols.exercise,
                      title: l10n.trackerNoExercisesTitle,
                      description: l10n.trackerNoExercisesMessage,
                      actionLabel: l10n.trackerAddExercise,
                      onAction: () => unawaited(_addExercises(context)),
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
      ),
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
    final session = state.session!;
    return Tick(
      builder: (context, now) {
        final clock = state.isPaused
            ? l10n.trackerPaused
            : AppFormat.duration(state.elapsedAt(now));
        final date = AppFormat.date(
          session.dateCreated.toLocal(),
          style: AppDateStyle.weekdayDayMonth,
          locale: context.dateLocale,
        );
        return MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.sectionTitle,
              ),
              Text('$date · $clock', style: AppTextStyles.label.tabular),
            ],
          ),
        );
      },
    );
  }
}

enum _MenuAction { pause, finish, notes, workoutSettings, gym, discard }

class _Menu extends StatelessWidget {
  const new({required this.state, required this.compact});

  final ActiveWorkoutState state;

  /// Whether pause, finish and notes are in the menu rather than on the
  /// bar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<_MenuAction>(
      tooltip: l10n.trackerOptions,
      icon: Icon(AppSymbols.more),
      onSelected: (action) => switch (action) {
        _MenuAction.pause => context.read<ActiveWorkoutCubit>().togglePause(),
        _MenuAction.finish => unawaited(finishWorkout(context)),
        _MenuAction.notes => unawaited(_workoutNotes(context, state)),
        _MenuAction.workoutSettings => _workoutSettings(context),
        _MenuAction.gym => _gymSettings(context),
        _MenuAction.discard => unawaited(_discard(context)),
      },
      itemBuilder: (_) => [
        if (compact) ...[
          AppMenuItem(
            value: _MenuAction.pause,
            icon: state.isPaused ? AppSymbols.start : AppSymbols.pause,
            label: state.isPaused ? l10n.trackerResume : l10n.trackerPause,
          ),
          AppMenuItem(
            value: _MenuAction.finish,
            icon: AppSymbols.selected,
            label: l10n.trackerFinishMenu,
          ),
          AppMenuItem(
            value: _MenuAction.notes,
            icon: AppSymbols.note,
            label: l10n.trackerNotesMenu,
          ),
          const PopupMenuDivider(),
        ],
        AppMenuItem(
          value: _MenuAction.workoutSettings,
          icon: AppSymbols.settings,
          label: l10n.settingsWorkoutSettings,
        ),
        // Offered only when the workout has a gym to show.
        if (state.gym != null)
          AppMenuItem(
            value: _MenuAction.gym,
            icon: AppSymbols.gym,
            label: l10n.gymSettingsMenu,
          ),
        const PopupMenuDivider(),
        AppMenuItem(
          value: _MenuAction.discard,
          icon: AppSymbols.delete,
          label: l10n.trackerDiscard,
          isDestructive: true,
        ),
      ],
    );
  }

  /// Workout Settings over the tracker; the tracker follows a change at
  /// once.
  void _workoutSettings(BuildContext context) {
    context.read<ActiveWorkoutCubit>().workoutSettingsOpened();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WorkoutSettingsPage()),
    );
  }

  void _gymSettings(BuildContext context) {
    final gym = state.gym;
    if (gym == null) return;
    context.read<ActiveWorkoutCubit>().gymSettingsOpened();
    unawaited(GymProfilePage.push(context, gym));
  }

  Future<void> _discard(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<ActiveWorkoutCubit>()..discardPressed();
    final discard = await AppDialog.confirmDestructive(
      context,
      title: l10n.trackerDiscardTitle,
      message: l10n.trackerDiscardMessage,
      confirmLabel: l10n.trackerDiscardConfirm,
      cancelLabel: l10n.trackerCancel,
    );
    if (!discard) return;
    await cubit.discard();
    if (context.mounted) closeTracker(context);
  }
}

/// The workout's own note, from the bar or the menu.
Future<void> _workoutNotes(
  BuildContext context,
  ActiveWorkoutState state,
) async {
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
    final choice = await showAppDialog<_NoSetsChoice>(
      context: context,
      title: l10n.trackerNoSetsTitle,
      actions: [
        AppDialogAction(label: l10n.trackerCancel, role: AppDialogRole.cancel),
        AppDialogAction(
          label: l10n.trackerDiscard,
          value: _NoSetsChoice.discard,
          role: AppDialogRole.destructive,
        ),
        AppDialogAction(
          label: l10n.trackerSaveAnyway,
          value: _NoSetsChoice.save,
        ),
      ],
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
  final firstDay = firstDayOfWeekIndex(context);
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
    // No panel of its own: the button floats on the screen's canvas, as
    // Swift's does, with the correction card and keypad under it.
    return Material(
      type: MaterialType.transparency,
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
                if (keypad != null)
                  SetKeypadView(
                    keypad: keypad,
                    exercise: state.exercise(keypad.exerciseId),
                    member: state.card
                        .where((m) => m.exercise.id == keypad.exerciseId)
                        .firstOrNull,
                    actions: context.read<ActiveWorkoutCubit>(),
                    rirTracking: state.settings?.rirTracking ?? false,
                    showsPlates: state.showsPlates,
                    plateCalculator: state.plateCalculatorSetup,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// What is happening now, at arm's length (design-language.md, "Live"):
/// the rest's countdown and its bar while it runs, else the next set's
/// figures, in the display face at its largest. Hidden when there is
/// neither, such as once every set is logged.
class _Now extends StatelessWidget {
  const new({required this.state});

  final ActiveWorkoutState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Tick(
      builder: (context, now) {
        final end = state.restEnd;
        final left = end?.difference(now);
        final String overline;
        final String figure;
        double? fraction;
        if (left != null && !left.isNegative) {
          overline = l10n.trackerLiveRest;
          figure = AppFormat.duration(left + const Duration(milliseconds: 999));
          final length = state.restLength;
          fraction = length == null || length.inMilliseconds == 0
              ? 1
              : 1 - left.inMilliseconds / length.inMilliseconds;
        } else if (state.primaryAction case r.LogSetAction(:final setId)) {
          final set = state.set(setId);
          final exercise = state.exerciseHolding(setId);
          final figures = set == null || exercise == null
              ? null
              : TrackerText.figures(
                  l10n,
                  set,
                  exercise.trackingMode,
                  exercise.weightUnit ?? ExerciseWeightUnit.kilograms,
                  locale: locale,
                );
          if (set == null || exercise == null || figures == null) {
            return const SizedBox.shrink();
          }
          final name = switch (set) {
            WorkoutSetModel(isWarmup: true) => l10n.trackerSetTypeWarmup,
            WorkoutSetModel(parentSetId: final _?) => l10n.trackerSetTypeDrop,
            _ => l10n.trackerSetName(TrackerText.badge(l10n, set, exercise)),
          };
          overline = '$name · ${exercise.name}';
          figure = figures;
        } else {
          return const SizedBox.shrink();
        }
        final secondaryOverline = AppTextStyles.overline.secondary(context);
        return Semantics(
          container: true,
          label: overline,
          value: figure,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              AppSpacing.m,
            ),
            child: Column(
              spacing: AppSpacing.xxs,
              children: [
                Text(
                  overline.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: secondaryOverline,
                ),
                // Already larger than any text size makes body text, and
                // growing it would push the sets off the screen.
                MediaQuery.withNoTextScaling(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(figure, maxLines: 1, style: AppTextStyles.hero),
                  ),
                ),
                // The bar's room is kept for a set too, so the card under
                // it stays put as a rest starts and ends.
                SizedBox(
                  height: AppSpacing.xs,
                  child: fraction == null
                      ? null
                      : LinearProgressIndicator(
                          value: fraction.clamp(0, 1).toDouble(),
                          minHeight: AppSpacing.xs,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(AppRadius.s),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
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
    // What the button is called, short enough to say, with the rest of its
    // words as its value: Voice Control and Voice Access match the name,
    // as Swift's input labels do ("Log Set 2", "Skip Rest", "Next").
    String name;
    String? value;
    switch (slot) {
      case r.SlotLog(:final setId):
        final set = state.set(setId);
        final exercise = state.exerciseHolding(setId);
        title = set == null || exercise == null
            ? ''
            : TrackerText.logTitle(l10n, set, exercise, locale: locale);
        final [first, ...rest] = title.split(' · ');
        name = first;
        value = rest.isEmpty ? null : rest.join(' · ');
        if (isLarge) title = first;
        if (inGrace) title = l10n.trackerRestDone(title);
      case r.SlotNext(:final exerciseId):
        final exerciseName = state.exercise(exerciseId)?.name ?? '';
        title = l10n.trackerNext(exerciseName);
        name = l10n.trackerNextShort;
        value = exerciseName;
      case r.SlotFinish():
        title = name = l10n.trackerFinishTitle;
      case r.SlotResume():
        title = name = l10n.trackerResume;
      case r.SlotSkipRest():
        final left = state.restEnd!.difference(now);
        final clock = AppFormat.duration(
          left + const Duration(milliseconds: 999),
        );
        // The countdown is already up top, at its largest, unless the
        // keypad has taken its place.
        title = isLarge || state.keypad == null
            ? l10n.trackerSkipRest
            : '${l10n.trackerSkipRest} $clock';
        name = l10n.trackerSkipRest;
        value = clock;
    }
    final onPressed = inGrace
        ? null
        : slot is r.SlotFinish
        ? () => unawaited(finishWorkout(context))
        : cubit.pressPrimary;
    final button = Semantics(
      key: const Key('WorkoutTracker.primary'),
      button: true,
      enabled: onPressed != null,
      label: name,
      value: value,
      onTap: onPressed,
      excludeSemantics: true,
      child: AppCtaButton(label: title, onPressed: onPressed),
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
