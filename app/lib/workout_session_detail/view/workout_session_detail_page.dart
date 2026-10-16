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
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound/workout_session_detail/bloc/workout_session_detail_bloc.dart';
import 'package:compound/workout_session_detail/cubit/session_strava_cubit.dart';
import 'package:compound/workout_session_detail/view/set_detail_row.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// One finished workout, read-only: when it started, how long it took, its
/// volume and notes, then each exercise with its sets. A port of the Swift
/// app's `WorkoutSessionDetailView` without editing, deleting or Copy Link.
/// Share Image draws the workout's card; "View on Strava" opens the
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
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !isWorkoutSummary,
          title: Text(switch (state) {
            WorkoutSessionDetailLoaded(:final session) => session.name,
            _ => '',
          }),
          actions: [
            if (state case WorkoutSessionDetailLoaded(:final session)
                when session.endedAt != null)
              _ShareImageButton(session: session),
            if (isWorkoutSummary)
              TextButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(AppTab.today.path),
                child: Text(
                  l10n.summaryDone,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        body: switch (state) {
          WorkoutSessionDetailLoading() => const Center(
            child: CircularProgressIndicator.adaptive(),
          ),
          WorkoutSessionDetailNotFound() => _Message(
            text: l10n.workoutSessionNotFound,
          ),
          WorkoutSessionDetailFailure() => _Message(
            text: l10n.workoutSessionLoadFailure,
            canRetry: true,
          ),
          final WorkoutSessionDetailLoaded loaded => _Detail(state: loaded),
        },
      ),
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

class _Detail extends StatelessWidget {
  const new({required this.state});

  final WorkoutSessionDetailLoaded state;

  static String? _uid(BuildContext context) =>
      switch (context.read<AppBloc>().state) {
        AppAuthenticated(:final user) => user.uid,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final session = state.session;
    final duration = session.activeDuration;
    final notes = session.notes?.trim();
    final volume = session.loggedVolumeKg;
    final distanceUnit = WorkoutText.preferredDistanceUnit(state.distanceUnit);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            header: l10n.workoutDetailsHeader,
            children: [
              AppListRow(
                title: l10n.workoutStartTime,
                subtitle: DateFormat.yMMMMd(locale)
                    .add_jm()
                    .format(session.dateCreated.toLocal()),
                icon: AppSymbols.calendar,
              ),
              if (duration != null)
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
              if (notes != null && notes.isNotEmpty)
                AppListRow(title: notes, icon: AppSymbols.note),
              // The author's own finished workouts only: the coach reads
              // the asker's data, never someone else's.
              if (session.endedAt != null && session.authorId == _uid(context))
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
