import 'package:compound/workout_history/workout_history.dart';
import 'package:compound_models/compound_models.dart';

/// [session] with its highlights, read off [history]: the author's other
/// sessions the reader can see (`WorkoutSessionRowPresenter.init`).
WorkoutHistoryEntry feedEntry(
  WorkoutSessionModel session,
  List<WorkoutSessionModel> history, {
  required int firstDayOfWeek,
}) {
  final byAuthor = [
    for (final other in history)
      if (other.authorId == session.authorId) other,
  ];
  return WorkoutHistoryEntry(
    session: session,
    personalRecords: WorkoutSessionHighlights.personalRecords(
      session,
      priorSessions: byAuthor,
    ),
    weeklyWorkoutNumber: WorkoutSessionHighlights.weeklyWorkoutNumber(
      session,
      history: byAuthor,
      firstDayOfWeek: firstDayOfWeek,
    ),
  );
}
