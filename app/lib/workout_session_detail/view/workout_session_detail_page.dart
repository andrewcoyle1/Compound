import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/coach/coach.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/sharing/share_card/share_workout_card.dart';
import 'package:compound/sharing/share_card/workout_share_card.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/training_library/view/exercise_picker_page.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound/workout_session_detail/bloc/workout_session_detail_bloc.dart';
import 'package:compound/workout_session_detail/cubit/session_edit_cubit.dart';
import 'package:compound/workout_session_detail/cubit/session_strava_cubit.dart';
import 'package:compound/workout_session_detail/view/session_exercise_editor.dart';
import 'package:compound/workout_session_detail/view/session_timing_sheets.dart';
import 'package:compound/workout_session_detail/view/set_detail_row.dart';
import 'package:compound/workout_tracker/logic/set_keypad.dart'
    show SetKeypad;
import 'package:compound/workout_tracker/view/set_keypad_view.dart';
import 'package:compound/workout_tracker/view/set_row_parts.dart'
    show confirmDestructive;
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show TrainingLibraryRepository;
import 'package:training_session/training_session.dart'
    show UnitPreferenceStore;
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// One finished workout: when it started, how long it took, its volume and
/// notes, then each exercise with its sets. A port of the Swift app's
/// `WorkoutSessionDetailView` without Copy Link. Its author can move its
/// start, change its duration, edit it (sets, notes, exercises) and delete
/// it. Share Image draws the workout's card; "View on Strava" opens the
/// activity, and the summary of a first workout offers Strava once.
///
/// As the summary of a workout just finished (`isWorkoutSummary`), it opens
/// over the tabs in the tracker's place, shows the [session] it is handed
/// rather than waiting for the save, and Done closes it.
class WorkoutSessionDetailPage extends StatelessWidget {
  const new({
    required this.sessionId,
    this.session,
    this.isWorkoutSummary = false,
    super.key,
  });

  /// The summary's path, over the tabs.
  static const summaryPath = '/workout-summary/:$sessionIdParameter';

  /// The summary's route name.
  static const summaryName = 'workoutSummary';

  /// The path under the workout history.
  static const path = ':$sessionIdParameter';

  /// The route name.
  static const name = 'workoutSessionDetail';

  /// The path parameter carrying the session id.
  static const sessionIdParameter = 'sessionId';

  /// The workout to show.
  final String sessionId;

  /// The workout itself, when the caller has it.
  final WorkoutSessionModel? session;

  /// The summary of the workout just finished.
  final bool isWorkoutSummary;

  @override
  Widget build(BuildContext context) {
    // The router only shows this page while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => WorkoutSessionDetailBloc(
            sessionRepository: context.read<WorkoutSessionRepository>(),
            userRepository: context.read<UserRepository>(),
            uid: state.user.uid,
            sessionId: sessionId,
            session: session,
          )..add(const WorkoutSessionDetailRequested()),
        ),
        BlocProvider(
          create: (context) => SessionStravaCubit(
            sessions: context.read<WorkoutSessionRepository>(),
            analytics: context.read(),
            strava: context.read<StravaRepository?>(),
            uid: state.user.uid,
            sessionId: sessionId,
            session: session,
            isWorkoutSummary: isWorkoutSummary,
          )..started(),
        ),
      ],
      child: WorkoutSessionDetailView(isWorkoutSummary: isWorkoutSummary),
    );
  }
}

class WorkoutSessionDetailView extends StatelessWidget {
  const new({this.isWorkoutSummary = false, super.key});

  final bool isWorkoutSummary;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkoutSessionDetailBloc>().state;
    final l10n = context.l10n;
    return MultiBlocListener(
      listeners: [
        BlocListener<SessionStravaCubit, SessionStravaState>(
          listenWhen: (previous, current) =>
              current.offerId != previous.offerId,
          listener: (context, _) => unawaited(_offerStrava(context)),
        ),
        // A connection the offer started that failed.
        BlocListener<StravaCubit, StravaState>(
          listenWhen: (previous, current) =>
              isWorkoutSummary && current.noticeId != previous.noticeId,
          listener: showStravaNotice,
        ),
      ],
      child: switch (state) {
        final WorkoutSessionDetailLoaded loaded => BlocProvider(
          key: ValueKey(loaded.session.id),
          create: (context) => SessionEditCubit(
            session: loaded.session,
            sessions: context.read<WorkoutSessionRepository>(),
            users: context.read<UserRepository>(),
            analytics: context.read(),
            library: context.read<TrainingLibraryRepository>(),
            strava: context.read<StravaRepository?>(),
            units: context.read<UnitPreferenceStore>(),
            uid: switch (context.read<AppBloc>().state) {
              AppAuthenticated(:final user) => user.uid,
              _ => null,
            },
          ),
          child: _LoadedView(state: loaded, isWorkoutSummary: isWorkoutSummary),
        ),
        _ => Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !isWorkoutSummary,
            actions: [
              if (isWorkoutSummary)
                _DoneButton(onPressed: () => _leave(context, summary: true)),
            ],
          ),
          body: switch (state) {
            WorkoutSessionDetailNotFound() => _Message(
              text: l10n.workoutSessionNotFound,
            ),
            WorkoutSessionDetailFailure() => _Message(
              text: l10n.workoutSessionLoadFailure,
              canRetry: true,
            ),
            _ => const Center(child: CircularProgressIndicator.adaptive()),
          },
        ),
      },
    );
  }

  /// "Upload Workouts to Strava?" over the summary of a first workout.
  static Future<void> _offerStrava(BuildContext context) async {
    final l10n = context.l10n;
    final offer = context.read<SessionStravaCubit>();
    final strava = context.read<StravaCubit>();
    final connect = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.stravaOfferTitle),
        content: Text(l10n.stravaOfferMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.stravaNotNow),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.stravaOfferConnect),
          ),
        ],
      ),
    );
    final accepted = connect ?? false;
    await offer.offerAnswered(connect: accepted);
    if (accepted) await strava.connect(fromOffer: true);
  }
}

/// Leaves the screen: the summary closes over the tabs, a pushed workout
/// goes back to its list.
void _leave(BuildContext context, {required bool summary}) {
  if (context.canPop()) return context.pop();
  if (summary) context.go(AppTab.today.path);
}

/// The locale's first day of the week (ISO), as the streak counts weeks.
int _firstWeekday(BuildContext context) {
  final first = MaterialLocalizations.of(context).firstDayOfWeekIndex;
  return first == 0 ? DateTime.sunday : first;
}

class _DoneButton extends StatelessWidget {
  const new({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    child: Text(
      context.l10n.summaryDone,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}

/// The workout once read: read, or edited by its author.
class _LoadedView extends StatelessWidget {
  const new({required this.state, required this.isWorkoutSummary});

  final WorkoutSessionDetailLoaded state;
  final bool isWorkoutSummary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.watch<SessionEditCubit>();
    final edit = cubit.state;
    final session = edit.session;
    return MultiBlocListener(
      listeners: [
        BlocListener<SessionEditCubit, SessionEditState>(
          listenWhen: (previous, current) =>
              current.noticeId != previous.noticeId,
          listener: _showNotice,
        ),
        BlocListener<SessionEditCubit, SessionEditState>(
          listenWhen: (previous, current) =>
              current.savedId != previous.savedId,
          listener: (_, _) => unawaited(HapticFeedback.successNotification()),
        ),
        BlocListener<SessionEditCubit, SessionEditState>(
          listenWhen: (previous, current) =>
              current.isDeleted && !previous.isDeleted,
          listener: (context, _) => _leave(context, summary: isWorkoutSummary),
        ),
      ],
      // Back would leave unsaved edits behind: while editing it ends the
      // edit instead, asking first when anything changed.
      child: PopScope(
        canPop: !edit.isEditing,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_endEditing(context));
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !isWorkoutSummary && !edit.isEditing,
            leading: edit.isEditing
                ? IconButton(
                    key: const ValueKey('session-end-editing'),
                    icon: const Icon(AppSymbols.close),
                    tooltip: l10n.socialClose,
                    onPressed: () => unawaited(_endEditing(context)),
                  )
                : null,
            title: Text(session.name),
            actions: [
              if (session.endedAt != null) _ShareImageButton(session: session),
              if (edit.isEditing)
                IconButton(
                  key: const ValueKey('session-save'),
                  icon: const Icon(AppSymbols.selected),
                  tooltip: l10n.trackerSave,
                  onPressed: edit.hasUnsavedChanges && !edit.isSaving
                      ? () => unawaited(
                          cubit.saveChanges(
                            firstWeekday: _firstWeekday(context),
                          ),
                        )
                      : null,
                )
              else if (isWorkoutSummary)
                _DoneButton(onPressed: () => _leave(context, summary: true)),
              if (!edit.isEditing && cubit.state.isAuthor) const _MoreMenu(),
            ],
          ),
          body: _Detail(state: state),
          bottomNavigationBar: edit.keypad == null
              ? null
              : _Keypad(state: edit, keypad: edit.keypad!),
        ),
      ),
    );
  }

  /// Leaves editing, asking before throwing anything away
  /// (`onEndEditingPressed`).
  static Future<void> _endEditing(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<SessionEditCubit>();
    if (!cubit.state.hasUnsavedChanges) return cubit.endEditing();
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.discardChangesTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.keepEditingButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.danger,
            ),
            child: Text(l10n.discardChangesButton),
          ),
        ],
      ),
    );
    if (discard ?? false) cubit.discardChanges();
  }

  static void _showNotice(BuildContext context, SessionEditState state) {
    final l10n = context.l10n;
    final (title, message) = switch (state.notice) {
      SessionEditNotice.saveFailed => (
        l10n.editorSaveFailed,
        l10n.sessionSaveChangesFailed,
      ),
      SessionEditNotice.timingSaveFailed => (
        l10n.editorSaveFailed,
        l10n.sessionSaveTimingFailed,
      ),
      SessionEditNotice.deleteFailed => (
        l10n.editorDeleteFailed,
        l10n.editorTryAgain,
      ),
      SessionEditNotice.exerciseNoteFailed => (
        l10n.trackerNoteSaveFailed,
        l10n.editorTryAgain,
      ),
      SessionEditNotice.gymSaveFailed => (
        l10n.trackerUnableToSaveGym,
        l10n.gymCheckConnection,
      ),
      SessionEditNotice.logProblem || null => (
        l10n.trackerLogRefusedTitle,
        switch (state.logProblem) {
          final problem? => TrackerText.problem(l10n, problem),
          null => '',
        },
      ),
    };
    unawaited(HapticFeedback.errorNotification());
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }
}

enum _MoreAction { edit, delete }

/// Edit Workout and Delete, for the author.
class _MoreMenu extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopupMenuButton<_MoreAction>(
      key: const ValueKey('session-more'),
      icon: Icon(AppSymbols.more),
      tooltip: l10n.programMore,
      onSelected: (action) => switch (action) {
        _MoreAction.edit => unawaited(
          context.read<SessionEditCubit>().enterEditMode(),
        ),
        _MoreAction.delete => unawaited(_delete(context)),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _MoreAction.edit,
          child: ListTile(
            leading: const Icon(AppSymbols.edit),
            title: Text(l10n.editorEditWorkout),
          ),
        ),
        PopupMenuItem(
          value: _MoreAction.delete,
          child: ListTile(
            leading: Icon(AppSymbols.delete, color: context.appColors.danger),
            title: Text(
              l10n.editorDelete,
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> _delete(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<SessionEditCubit>();
    final firstWeekday = _firstWeekday(context);
    final delete = await confirmDestructive(
      context,
      title: l10n.sessionDeleteTitle,
      message: l10n.sessionDeleteMessage,
      action: l10n.editorDelete,
    );
    if (delete) await cubit.delete(firstWeekday: firstWeekday);
  }
}

class _Detail extends StatelessWidget {
  const new({required this.state});

  /// The workout as read, for the profile's units.
  final WorkoutSessionDetailLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final cubit = context.read<SessionEditCubit>();
    final edit = context.watch<SessionEditCubit>().state;
    final session = edit.session;
    final isAuthor = cubit.state.isAuthor;
    final duration = session.activeDuration;
    final notes = session.notes?.trim();
    final volume = session.loggedVolumeKg;
    final distanceUnit = WorkoutText.preferredDistanceUnit(state.distanceUnit);
    final started = DateFormat.yMMMMd(locale)
        .add_jm()
        .format(session.dateCreated.toLocal());
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            header: l10n.workoutDetailsHeader,
            children: [
              if (isAuthor)
                AppListRowButton(
                  title: l10n.workoutStartTime,
                  subtitle: started,
                  icon: AppSymbols.calendar,
                  onPressed: () => unawaited(_editStart(context)),
                )
              else
                AppListRow(
                  title: l10n.workoutStartTime,
                  subtitle: started,
                  icon: AppSymbols.calendar,
                ),
              if (duration != null)
                if (isAuthor)
                  AppListRowButton(
                    title: l10n.statDuration,
                    subtitle: AppFormat.duration(duration),
                    icon: AppSymbols.duration,
                    onPressed: () => unawaited(_editDuration(context)),
                  )
                else
                  AppListRow(
                    title: l10n.statDuration,
                    subtitle: AppFormat.duration(duration),
                    icon: AppSymbols.duration,
                  ),
              AppListRow(
                title: l10n.statVolume,
                icon: AppSymbols.volume,
                accessory: AppListRowValue(
                  volume > 0
                      ? AppFormat.weight(
                          volume,
                          WorkoutText.preferredWeightUnit(state.weightUnit),
                          locale: locale,
                        )
                      : AppFormat.placeholder,
                ),
              ),
              if (edit.isEditing)
                _NotesField(initial: session.notes ?? '')
              else if (notes != null && notes.isNotEmpty)
                AppListRow(title: notes, icon: AppSymbols.note),
              // The author's own finished workouts only: the coach reads
              // the asker's data, never someone else's.
              if (session.endedAt != null && isAuthor && !edit.isEditing)
                AppListRowButton(
                  title: l10n.coachAskAboutWorkout,
                  icon: AppSymbols.coach,
                  onPressed: () => CoachPage.open(
                    context,
                    CoachContext(
                      kind: CoachContextKind.session,
                      id: session.id,
                      title: session.name,
                    ),
                  ),
                ),
              // Edits in place rather than opening a screen: no chevron.
              if (isAuthor && !edit.isEditing)
                AppListRowButton(
                  key: const ValueKey('session-edit'),
                  title: l10n.editorEditWorkout,
                  icon: AppSymbols.edit,
                  accessory: null,
                  onPressed: () => unawaited(cubit.enterEditMode()),
                ),
              if (context.watch<SessionStravaCubit>().state.link
                  case final link?)
                AppListRowButton(
                  title: l10n.stravaViewOn,
                  icon: AppSymbols.openExternally,
                  accessory: null,
                  onPressed: () {
                    context.read<SessionStravaCubit>().viewOnStravaPressed();
                    unawaited(context.read<LinkOpener>().open(link));
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (edit.isEditing) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.exerciseDetailsHeader,
                    style: AppTextStyles.label.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  key: const ValueKey('session-add-exercise'),
                  icon: const Icon(AppSymbols.add),
                  tooltip: l10n.editorAddExercise,
                  onPressed: () => unawaited(_addExercises(context)),
                ),
              ],
            ),
            for (final member in edit.members) ...[
              const SizedBox(height: AppSpacing.l),
              SessionExerciseEditor(
                key: ValueKey(member.exercise.id),
                member: member,
              ),
            ],
          ] else
            for (final (index, exercise) in session.exercises.indexed) ...[
              if (index > 0) const SizedBox(height: AppSpacing.l),
              AppSection(
                header: index == 0 ? l10n.exerciseDetailsHeader : null,
                children: [
                  AppListRow(
                    title: exercise.name,
                    subtitle: WorkoutText.exerciseSummary(
                      l10n,
                      exercise,
                      locale: locale,
                    ),
                    icon: AppSymbols.exercise,
                  ),
                  if (exercise.notes case final note? when note.isNotEmpty)
                    AppListRow(title: note, icon: AppSymbols.note),
                  for (final set in exercise.sets)
                    SetDetailRow(
                      set: set,
                      number: exercise.workingSetNumber(set),
                      trackingMode: exercise.trackingMode,
                      weightUnit: exercise.displayWeightUnit,
                      distanceUnit: distanceUnit,
                    ),
                ],
              ),
            ],
        ],
      ),
    );
  }

  /// Start Time: saved from the sheet, keeping the duration.
  static Future<void> _editStart(BuildContext context) async {
    final cubit = context.read<SessionEditCubit>();
    final firstWeekday = _firstWeekday(context);
    final picked = await showSessionStartTimeSheet(
      context,
      cubit.state.session.dateCreated,
    );
    if (picked != null) {
      await cubit.changeStart(picked.toUtc(), firstWeekday: firstWeekday);
    }
  }

  /// Duration: saved from the sheet, opening on what it lasted.
  static Future<void> _editDuration(BuildContext context) async {
    final cubit = context.read<SessionEditCubit>();
    final firstWeekday = _firstWeekday(context);
    final seconds = cubit.state.session.activeDuration?.inSeconds ?? 0;
    final picked = await showSessionDurationSheet(
      context,
      hours: seconds ~/ 3600,
      minutes: seconds % 3600 ~/ 60,
    );
    if (picked case (final hours, final minutes)) {
      await cubit.changeDuration(hours, minutes, firstWeekday: firstWeekday);
    }
  }

  /// Add Exercise, through the exercise picker.
  static Future<void> _addExercises(BuildContext context) async {
    final cubit = context.read<SessionEditCubit>();
    final picked = await ExercisePickerPage.show(context);
    if (picked != null) cubit.addExercises(picked);
  }
}

/// The tracker's keypad, docked at the foot while it types into a set.
class _Keypad extends StatelessWidget {
  const new({required this.state, required this.keypad});

  final SessionEditState state;
  final SetKeypad keypad;

  @override
  Widget build(BuildContext context) {
    final member = state.member(keypad.exerciseId);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SetKeypadView(
          keypad: keypad,
          exercise: member?.exercise,
          member: member,
          actions: context.read<SessionEditCubit>(),
          rirTracking: state.settings?.rirTracking ?? false,
          showsPlates: state.showsPlates,
          plateCalculator: state.plateCalculatorSetup,
        ),
      ),
    );
  }
}

/// The workout's notes while editing; a blank field clears them.
class _NotesField extends StatefulWidget {
  const new({required this.initial});

  final String initial;

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: TextField(
        key: const ValueKey('session-notes'),
        controller: _controller,
        minLines: 3,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: l10n.sessionNotesLabel,
          hintText: l10n.sessionNotesPrompt,
        ),
        onChanged: context.read<SessionEditCubit>().setNotes,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const new({required this.text, this.canRetry = false});

  final String text;
  final bool canRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.l,
          children: [
            AppInlineMessage(
              kind: AppInlineMessageKind.error,
              text: text,
              kindLabel: l10n.errorLabel,
            ),
            if (canRetry)
              TextButton(
                onPressed: () => context.read<WorkoutSessionDetailBloc>().add(
                  const WorkoutSessionDetailRequested(),
                ),
                child: Text(l10n.tryAgainButton),
              ),
          ],
        ),
      ),
    );
  }
}

/// Share Image, Story or Square (`WorkoutSessionDetailView`'s menu). The
/// card names the author when the circle knows them, and reads its records
/// off the author's sessions the circle holds.
class _ShareImageButton extends StatefulWidget {
  const new({required this.session});

  final WorkoutSessionModel session;

  @override
  State<_ShareImageButton> createState() => _ShareImageButtonState();
}

class _ShareImageButtonState extends State<_ShareImageButton> {
  bool _rendering = false;

  Future<void> _share(ShareCardFormat format) async {
    final circle = context.read<CircleBloc>().state;
    final session = widget.session;
    setState(() => _rendering = true);
    await shareWorkoutCard(
      context,
      session,
      author: circle.authorOf(session),
      history: [
        for (final other in circle.sessions)
          if (other.authorId == session.authorId) other,
      ],
      format: format,
    );
    if (mounted) setState(() => _rendering = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_rendering) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.l),
        child: SizedBox.square(
          dimension: AppSpacing.l,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
      );
    }
    return PopupMenuButton<ShareCardFormat>(
      icon: Icon(AppSymbols.share),
      tooltip: l10n.shareImage,
      onSelected: (format) => unawaited(_share(format)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: ShareCardFormat.story,
          child: Text(l10n.shareImageStory),
        ),
        PopupMenuItem(
          value: ShareCardFormat.square,
          child: Text(l10n.shareImageSquare),
        ),
      ],
    );
  }
}
