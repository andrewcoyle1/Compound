/// The small rules screens ask about Strava (Swift `StravaOffer`,
/// `WorkoutSessionDetailPresenter.stravaLink`, `StravaTotals`).
library;

import 'package:compound_models/compound_models.dart';

/// Whether [finished] is the moment to offer Strava (Swift
/// `StravaOffer.shouldOffer`): it is offered once, over the session detail
/// of the first workout a person finishes, and never again after they
/// answer. Strava is not connected, the offer has not been answered,
/// [finished] has saved, and no other finished workout of the same author
/// exists. Rest days and deleted sessions are not workouts the person
/// finished.
bool shouldOfferStrava({
  required WorkoutSessionModel finished,
  required List<WorkoutSessionModel> savedSessions,
  required bool isStravaConnected,
  required bool hasAnswered,
}) {
  if (isStravaConnected ||
      hasAnswered ||
      !_isFinishedWorkout(finished) ||
      !savedSessions.any((session) => session.id == finished.id)) {
    return false;
  }
  return !savedSessions.any(
    (session) =>
        session.id != finished.id &&
        session.authorId == finished.authorId &&
        _isFinishedWorkout(session),
  );
}

bool _isFinishedWorkout(WorkoutSessionModel session) =>
    session.endedAt != null && !session.isRestDay && session.deletedAt == null;

/// The activity [session] became on Strava, for [viewerId] only when they
/// are its author: someone else's Strava link is never shown. Read it from
/// the stored session, which gains the id once Strava has made the activity.
Uri? stravaActivityLink(
  WorkoutSessionModel session, {
  required String viewerId,
}) {
  final activityId = session.stravaActivityId;
  if (activityId == null || session.authorId != viewerId) return null;
  return Uri.https('www.strava.com', '/activities/$activityId');
}

/// A span's imported activities added up (Swift `StravaTotals`).
class const StravaTotals({
  /// How many there were.
  required final int count,

  /// Metres, all together.
  required final double distanceMeters,

  /// Seconds moving, all together.
  required final int movingTime,
}) {
  /// Creates a [StravaTotals].
  this;

  /// The activities starting in [start] up to but not including [end], or
  /// `null` when there were none.
  static StravaTotals? of(
    List<StravaImportedActivity> activities, {
    required DateTime start,
    required DateTime end,
  }) {
    final inSpan = [
      for (final activity in activities)
        if (!activity.startDate.isBefore(start) &&
            activity.startDate.isBefore(end))
          activity,
    ];
    if (inSpan.isEmpty) return null;
    return StravaTotals(
      count: inSpan.length,
      distanceMeters: inSpan.fold(
        0,
        (sum, activity) => sum + activity.distance,
      ),
      movingTime: inSpan.fold(0, (sum, activity) => sum + activity.movingTime),
    );
  }
}
