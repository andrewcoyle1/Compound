import 'package:compound/nutrition/logic/meal_day.dart' show dayKeyOf;
import 'package:compound/widgets/calendar/calendar_day_marker.dart';
import 'package:compound_models/compound_models.dart';

/// The workouts the Training calendar marks and opens: finished, not a rest
/// day and not deleted.
bool _isLoggedWorkout(WorkoutSessionModel session) =>
    session.endedAt != null && !session.isRestDay && session.deletedAt == null;

/// Each day's finished workouts as one marker, in the order they were done
/// and each in its mesocycle's colour (Swift `TrainingPresenter
/// .loggedWorkoutMarkersByDay`). Running workouts and rest days are left
/// out; a mesocycle since deleted, or none, takes the accent.
Map<String, CalendarDayMarker> loggedWorkoutMarkersByDay(
  Iterable<WorkoutSessionModel> sessions,
  Iterable<Mesocycle> mesocycles,
) {
  final colours = <String, String>{};
  for (final mesocycle in mesocycles) {
    colours.putIfAbsent(mesocycle.id, () => mesocycle.colour);
  }
  final byDay = <String, List<WorkoutSessionModel>>{};
  for (final session in sessions.where(_isLoggedWorkout)) {
    (byDay[dayKeyOf(session.dateCreated.toLocal())] ??= []).add(session);
  }
  return byDay.map(
    (day, sessions) => MapEntry(
      day,
      SessionsMarker([
        for (final session
            in sessions..sort((a, b) => a.dateCreated.compareTo(b.dateCreated)))
          colours[session.mesocycleId],
      ]),
    ),
  );
}

/// The finished workouts started on [day], earliest first (Swift
/// `TrainingPresenter.sessionsForDate`): tapping the day opens the one, or
/// asks which of several.
List<WorkoutSessionModel> loggedWorkoutsOn(
  Iterable<WorkoutSessionModel> sessions,
  DateTime day,
) {
  final key = dayKeyOf(day);
  return [
    for (final session in sessions)
      if (_isLoggedWorkout(session) &&
          dayKeyOf(session.dateCreated.toLocal()) == key)
        session,
  ]..sort((a, b) => a.dateCreated.compareTo(b.dateCreated));
}

/// The finished workout started last, or null before the first (the
/// Training tab's Last Workout).
WorkoutSessionModel? latestLoggedWorkout(
  Iterable<WorkoutSessionModel> sessions,
) => sessions
    .where(_isLoggedWorkout)
    .fold<WorkoutSessionModel?>(
      null,
      (latest, session) =>
          latest == null || session.dateCreated.isAfter(latest.dateCreated)
          ? session
          : latest,
    );
