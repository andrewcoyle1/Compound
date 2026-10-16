import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_history/models/workout_session_highlights.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:social_repository/social_repository.dart';

/// Everything the workout share card prints, as strings, so its wording is
/// tested without rendering it (`ShareCardContent`).
///
/// Privacy: the only person on the card is the session's author, and only
/// by first name and picture. No username, no last name, no comments, no
/// likers.
final class const ShareCardContent({
  required final String? firstName,
  required final String? avatarUrl,
  required final String sessionName,
  required final String dateText,
  required final String? durationText,
  required final String? volumeText,
  required final int setCount,
  required final List<String> personalRecordLines,
  required final String? weeklyText,
  required final String? streakText,
}) extends Equatable {
  /// The card for [session], with its records and weekly count read off
  /// the author's [history].
  factory fromHistory(
    AppLocalizations l10n,
    WorkoutSessionModel session, {
    required UserModel? author,
    required List<WorkoutSessionModel> history,
    required int firstDayOfWeek,
    String? locale,
  }) => ShareCardContent.make(
    l10n,
    session,
    author: author,
    personalRecords: WorkoutSessionHighlights.personalRecords(
      session,
      priorSessions: history,
    ),
    weeklyWorkoutNumber: WorkoutSessionHighlights.weeklyWorkoutNumber(
      session,
      history: history,
      firstDayOfWeek: firstDayOfWeek,
    ),
    locale: locale,
  );

  /// The card for [session] with its highlights already worked out.
  factory make(
    AppLocalizations l10n,
    WorkoutSessionModel session, {
    required UserModel? author,
    required List<PersonalRecord> personalRecords,
    required int weeklyWorkoutNumber,
    String? locale,
  }) => ShareCardContent(
    firstName: author == null ? null : firstNameOf(author),
    avatarUrl: author == null ? null : profileImageOf(author),
    sessionName: session.name,
    dateText: DateFormat.MMMMEEEEd(locale)
        .format(session.dateCreated.toLocal()),
    durationText: formatDuration(l10n, session.activeDuration),
    volumeText: formatVolume(
      session.loggedVolumeKg,
      unit: session.authorWeightUnit,
      locale: locale,
    ),
    // A left and a right are one set, as on the feed card.
    setCount: session.loggedSetCount,
    personalRecordLines: [
      for (final record in personalRecords)
        [
          record.exerciseName,
          WorkoutText.recordDetail(l10n, record, locale: locale),
        ].join(' '),
    ],
    weeklyText: WorkoutText.weeklyWorkout(l10n, weeklyWorkoutNumber),
    streakText: WorkoutText.streak(l10n, session.weekStreakCount),
  );

  /// "1h 5m", or "45m" under an hour; null for a session still running.
  static String? formatDuration(AppLocalizations l10n, Duration? duration) {
    if (duration == null) return null;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return hours > 0
        ? l10n.shareCardHoursMinutes(hours, minutes)
        : l10n.shareCardMinutes(minutes);
  }

  /// "12,340 kg" in the unit the author lifted in, grouped; null when
  /// nothing was lifted, so a run does not boast "0 kg".
  static String? formatVolume(
    double kilograms, {
    ExerciseWeightUnit unit = ExerciseWeightUnit.kilograms,
    String? locale,
  }) => kilograms <= 0
      ? null
      : AppFormat.weight(
          kilograms,
          WorkoutText.weightUnit(unit),
          maxFractionDigits: 0,
          locale: locale,
        );

  @override
  List<Object?> get props => [
    firstName,
    avatarUrl,
    sessionName,
    dateText,
    durationText,
    volumeText,
    setCount,
    personalRecordLines,
    weeklyText,
    streakText,
  ];
}
