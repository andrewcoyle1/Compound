import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound_models/compound_models.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// The session Start would begin from Today's card, built exactly as the
/// tracker builds it (`TodaysWorkoutCardPresenter.loadTargets`), so the
/// card promises what the tracker will show. Null until loaded, and stays
/// null when it cannot be built: the card works without it. Each card
/// builds its own, so one load per cubit.
class WorkoutPreviewCubit extends Cubit<WorkoutSessionModel?> {
  new({
    required this._library,
    required this._sessions,
    required this._users,
    required this._analytics,
    this._clock = DateTime.now,
  }) : super(null);

  final TrainingLibraryRepository _library;
  final WorkoutSessionRepository _sessions;
  final UserRepository _users;
  final AnalyticsRepository _analytics;
  final DateTime Function() _clock;

  /// Builds [template]'s session for [uid], on [microcycleIndex]'s targets
  /// (from 1) of [mesocycleId], cut to a deload's when [isDeload].
  Future<void> load(
    String uid,
    WorkoutTemplateModel template, {
    String? mesocycleId,
    int? microcycleIndex,
    bool isDeload = false,
  }) async {
    try {
      final library = [
        ...await _library.watchUserExercises(uid).first,
        ...PrebuiltCatalogue.instance.exercises,
      ];
      final gyms = [
        for (final gym in await _library.watchGymProfiles(uid).first)
          if (gym.deletedAt == null) gym,
      ];
      final favouriteId =
          (await _users.watchUser(uid).first)?.submittedFavouriteGymProfileId;
      final favourite = gyms.where((gym) => gym.id == favouriteId).firstOrNull;
      final now = _clock();
      final session = plannedSession(
        authorId: uid,
        template: template,
        library: library,
        history: SessionHistory(await _sessions.watchSessions(uid).first),
        settings: await _library.watchWorkoutSettings(uid).first,
        gyms: gyms,
        workoutGym: favourite,
        now: now,
        mesocycleId: mesocycleId,
        microcycleIndex: microcycleIndex,
      );
      if (isClosed) return;
      emit(
        isDeload
            ? deloadedSession(
                session,
                library: library,
                gym:
                    gyms
                        .where((gym) => gym.id == session.gymProfileId)
                        .firstOrNull ??
                    favourite,
                now: now,
              )
            : session,
      );
    } on Object catch (error) {
      _analytics.trackEvent(
        AnalyticsEvent(
          'TodaysWorkoutCard_LoadTargets_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.warning,
        ),
      );
    }
  }
}
