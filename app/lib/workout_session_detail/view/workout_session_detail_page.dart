import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/coach/coach.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/sharing/session_web_link.dart';
import 'package:compound/sharing/share_card/share_workout_card.dart';
import 'package:compound/sharing/share_card/workout_share_card.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/social_routes.dart' show SocialNavigation;
import 'package:compound/social/view/people_widgets.dart' show AuthorHeader;
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:compound/training_library/view/exercise_picker_page.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound/workout_session_detail/bloc/workout_session_detail_bloc.dart';
import 'package:compound/workout_session_detail/cubit/session_edit_cubit.dart';
import 'package:compound/workout_session_detail/cubit/session_strava_cubit.dart';
import 'package:compound/workout_session_detail/view/session_exercise_editor.dart';
import 'package:compound/workout_session_detail/view/session_timing_sheets.dart';
import 'package:compound/workout_session_detail/view/set_detail_row.dart';
import 'package:compound/workout_tracker/logic/set_keypad.dart' show SetKeypad;
import 'package:compound/workout_tracker/view/set_keypad_view.dart';
import 'package:compound/workout_tracker/view/tracker_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:social_repository/social_repository.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show TrainingLibraryRepository;
import 'package:training_session/training_session.dart'
    show UnitPreferenceStore;
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// One finished workout: when it started, how long it took, its volume and
/// notes, then each exercise with its sets. A port of the Swift app's
/// `WorkoutSessionDetailView`. Its author can move its start, change its
/// duration, edit it (sets, notes, exercises) and delete it. Share Image
/// draws the workout's card, Copy Link copies its web page; "View on
/// Strava" opens the activity, and the summary of a first workout offers
/// Strava once.
///
/// As the summary of a workout just finished (`isWorkoutSummary`), it opens
/// over the tabs in the tracker's place with a burst of confetti, shows the
/// [session] it is handed rather than waiting for the save, and Done closes
/// it.
class WorkoutSessionDetailPage extends StatelessWidget {
  const new({
    required this.sessionId,
    this.authorId,
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

  /// Who did it, when it may be someone else's; the signed-in user's
  /// otherwise.
  final String? authorId;

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
            socialRepository: context.read<SocialRepository>(),
            uid: state.user.uid,
            sessionId: sessionId,
            authorId: authorId,
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
      // A workout just finished is celebrated once, as its summary opens.
      child: AppConfetti(
        playsOnMount: isWorkoutSummary,
        child: WorkoutSessionDetailView(isWorkoutSummary: isWorkoutSummary),
      ),
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
            device: context.read<DeviceStore>(),
            uid: switch (context.read<AppBloc>().state) {
              AppAuthenticated(:final user) => user.uid,
              _ => null,
            },
          ),
          child: _LoadedView(state: loaded, isWorkoutSummary: isWorkoutSummary),
        ),
        _ => AppScaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !isWorkoutSummary,
            actions: [
              if (isWorkoutSummary)
                _DoneButton(onPressed: () => _leave(context, summary: true)),
            ],
          ),
          body: switch (state) {
            WorkoutSessionDetailNotFound() => AppEmptyState(
              icon: AppSymbols.workout,
              title: l10n.workoutSessionNotFound,
            ),
            WorkoutSessionDetailFailure() => AppErrorState(
              title: l10n.workoutSessionLoadFailure,
              actionLabel: l10n.tryAgainButton,
              onAction: () => context.read<WorkoutSessionDetailBloc>().add(
                const WorkoutSessionDetailRequested(),
              ),
            ),
            _ => AppLoadingView(label: l10n.launchLoading),
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
    final connect = await showAppDialog<bool>(
      context: context,
      title: l10n.stravaOfferTitle,
      message: l10n.stravaOfferMessage,
      actions: [
        AppDialogAction(
          label: l10n.stravaNotNow,
          value: false,
          role: AppDialogRole.cancel,
        ),
        AppDialogAction(
          label: l10n.stravaOfferConnect,
          value: true,
          role: AppDialogRole.preferred,
        ),
      ],
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
  final first = firstDayOfWeekIndex(context);
  return first == 0 ? DateTime.sunday : first;
}

/// The summary's confirm button, which closes it.
class _DoneButton extends StatelessWidget {
  const new({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => AppToolbarButton.confirm(
    semanticLabel: context.l10n.summaryDone,
    onPressed: onPressed,
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
          listener: (_, _) => unawaited(AppHaptics.success()),
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
        child: AppScaffold(
          appBar: AppBar(
            automaticallyImplyLeading: !isWorkoutSummary && !edit.isEditing,
            leading: edit.isEditing
                ? AppToolbarButton.close(
                    key: const ValueKey('session-end-editing'),
                    semanticLabel: l10n.socialClose,
                    onPressed: () => unawaited(_endEditing(context)),
                  )
                : null,
            title: _Title(session: session),
            actions: [
              if (session.endedAt != null) _ShareImageButton(session: session),
              if (edit.isEditing)
                AppToolbarButton.confirm(
                  key: const ValueKey('session-save'),
                  semanticLabel: l10n.trackerSave,
                  isSaving: edit.isSaving,
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
    final discard = await AppDialog.confirmDestructive(
      context,
      title: l10n.discardChangesTitle,
      confirmLabel: l10n.discardChangesButton,
      cancelLabel: l10n.keepEditingButton,
    );
    if (discard) cubit.discardChanges();
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
    unawaited(AppHaptics.error());
    unawaited(
      showAppDialog<void>(
        context: context,
        title: title,
        message: message,
        actions: [
          AppDialogAction(
            label: MaterialLocalizations.of(context).okButtonLabel,
            role: AppDialogRole.preferred,
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
        AppMenuItem(
          value: _MoreAction.edit,
          label: l10n.editorEditWorkout,
          icon: AppSymbols.edit,
        ),
        AppMenuItem(
          value: _MoreAction.delete,
          label: l10n.editorDelete,
          icon: AppSymbols.delete,
          isDestructive: true,
        ),
      ],
    );
  }

  static Future<void> _delete(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<SessionEditCubit>();
    final firstWeekday = _firstWeekday(context);
    final delete = await AppDialog.confirmDestructive(
      context,
      title: l10n.sessionDeleteTitle,
      message: l10n.sessionDeleteMessage,
      confirmLabel: l10n.editorDelete,
      cancelLabel: l10n.trackerCancel,
    );
    if (delete) await cubit.delete(firstWeekday: firstWeekday);
  }
}

/// The workout's title and, under it, when it started (Swift's
/// `navigationSubtitle`).
class _Title extends StatelessWidget {
  const new({required this.session});

  final WorkoutSessionModel session;

  @override
  Widget build(BuildContext context) {
    // Two lines in a fixed-height bar: at the size iOS draws an inline
    // title, which does not grow with the text size.
    return MediaQuery.withNoTextScaling(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(session.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            _started(context, session),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label.secondary(context),
          ),
        ],
      ),
    );
  }
}

/// "16 October 2026 at 13:00".
String _started(BuildContext context, WorkoutSessionModel session) =>
    AppFormat.dateTime(
      session.dateCreated.toLocal(),
      use24HourFormat: context.use24HourFormat,
      style: AppDateStyle.long,
      locale: context.dateLocale,
    );

class _Detail extends StatefulWidget {
  const new({required this.state});

  /// The workout as read, for the profile's units.
  final WorkoutSessionDetailLoaded state;

  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  /// The exercises opened onto their sets; each starts folded, as Swift's
  /// `DisclosureGroup`.
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.state;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final cubit = context.read<SessionEditCubit>();
    final edit = context.watch<SessionEditCubit>().state;
    final session = edit.session;
    final isAuthor = cubit.state.isAuthor;
    final duration = session.activeDuration;
    final notes = session.notes?.trim();
    final volume = session.loggedVolumeKg;
    final distanceUnit = WorkoutText.preferredDistanceUnit(state.distanceUnit);
    final started = _started(context, session);
    final author = context.select<CircleBloc, UserModel?>(
      (bloc) => bloc.state.authorOf(session),
    );
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          if (author != null) ...[
            AppSection(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.l,
                    vertical: AppSpacing.m,
                  ),
                  child: AuthorHeader(
                    author: author,
                    date: session.dateCreated,
                    onPressed: () =>
                        SocialNavigation.openProfile(context, author),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          AppSection(
            header: l10n.workoutDetailsHeader,
            children: [
              AppListRow(
                title: l10n.statVolume,
                icon: AppSymbols.volume,
                accessory: AppListRowCustom(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        volume > 0
                            ? AppFormat.weight(
                                volume,
                                WorkoutText.preferredWeightUnit(
                                  state.weightUnit,
                                ),
                                locale: locale,
                              )
                            : AppFormat.placeholder,
                        style: AppTextStyles.rowTitle.secondary(context),
                      ),
                      MethodInfoButton(MethodInfo.tonnage(l10n)),
                    ],
                  ),
                ),
              ),
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
              if (edit.isEditing)
                _NotesField(initial: session.notes ?? '')
              else if (notes != null && notes.isNotEmpty)
                AppListRow(title: notes, icon: AppSymbols.note),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (edit.isEditing) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.l),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.exerciseDetailsHeader,
                        style: AppTextStyles.sectionTitle.secondary(context),
                      ),
                    ),
                  ),
                  AppIconButton(
                    key: const ValueKey('session-add-exercise'),
                    icon: AppSymbols.add,
                    semanticLabel: l10n.editorAddExercise,
                    onPressed: () => unawaited(_addExercises(context)),
                  ),
                ],
              ),
            ),
            for (final member in edit.members) ...[
              const SizedBox(height: AppSpacing.l),
              SessionExerciseEditor(
                key: ValueKey(member.exercise.id),
                member: member,
              ),
            ],
          ] else if (session.exercises.isNotEmpty)
            AppSection(
              header: l10n.exerciseDetailsHeader,
              children: [
                for (final exercise in session.exercises) ...[
                  _ExerciseRow(
                    exercise: exercise,
                    summary: WorkoutText.exerciseSummary(
                      l10n,
                      exercise,
                      locale: locale,
                    ),
                    expanded: _expanded.contains(exercise.id),
                    onPressed: () => setState(
                      () => _expanded.contains(exercise.id)
                          ? _expanded.remove(exercise.id)
                          : _expanded.add(exercise.id),
                    ),
                  ),
                  if (_expanded.contains(exercise.id)) ...[
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
                ],
              ],
            ),
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

/// An exercise of the read workout: its picture, name and summary, opening
/// onto its sets (Swift's `DisclosureGroup` label).
class _ExerciseRow extends StatelessWidget {
  const new({
    required this.exercise,
    required this.summary,
    required this.expanded,
    required this.onPressed,
  });

  final WorkoutExerciseModel exercise;
  final String summary;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      expanded: expanded,
      child: AppListRowButton(
        title: exercise.name,
        subtitle: summary,
        thumbnail: ExerciseImage.named(
          name: exercise.name,
          image: exercise.imageName,
        ),
        accessory: AppListRowCustom(
          AnimatedRotation(
            turns: expanded ? 0.25 : 0,
            duration: AppMotion.quick.durationOf(context),
            child: Icon(
              AppSymbols.disclosure,
              size: AppIconSize.small.of(context),
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        onPressed: onPressed,
      ),
    );
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

/// Share Image, Story or Square, and Copy Link where the workout has a public
/// page (`WorkoutSessionDetailView`'s menu). The
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
    final session = widget.session;
    final link = context.read<SessionWebLink?>()?.url(
      session,
      author: context.select<CircleBloc, UserModel?>(
        (bloc) => bloc.state.authorOf(session),
      ),
    );
    if (_rendering) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.l),
        child: AppSpinner(size: AppSpinnerSize.small),
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
        if (link != null)
          PopupMenuItem(
            onTap: () => unawaited(_copyLink(link)),
            child: Text(l10n.copyLink),
          ),
      ],
    );
  }

  /// Copy Link (`WorkoutSessionDetailPresenter.onCopyLinkPressed`): the
  /// page's address on the clipboard, a success haptic for confirmation.
  Future<void> _copyLink(Uri link) async {
    context.read<AnalyticsRepository>().analytic(
      'WorkoutSessionDetailView_CopyLink',
      {'session_id': widget.session.id},
    );
    await Clipboard.setData(ClipboardData(text: '$link'));
    await AppHaptics.success();
  }
}
