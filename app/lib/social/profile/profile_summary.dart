import 'package:compound/social/circle/circle_bloc.dart';
import 'package:compound/social/logic/circle_week.dart';
import 'package:compound/social/logic/people.dart';
import 'package:compound_models/compound_models.dart';

/// What a profile shows the reader, worked out from the profile and the
/// reader's circle (`SocialProfilePresenter`'s computed properties).
final class ProfileSummary {
  new({
    required this.user,
    required CircleState circle,
    required List<WorkoutSessionModel> fetchedSessions,
    required DateTime now,
    required int firstDayOfWeek,
  }) : viewer = circle.viewer,
       isOwn = circle.viewer?.userId == user.userId,
       followState = circle.followState(user.userId),
       isBlocked = hasBlocked(circle.viewer, user.userId) {
    isLocked =
        (user.isPrivate ?? false) &&
        !isOwn &&
        followState != FollowState.following;
    final shown = [
      for (final session in isOwn ? circle.ownSessions : fetchedSessions)
        if (session.endedAt != null && !session.isRestDay) session,
    ]..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
    sessions = isLocked ? const [] : shown;
    final profileFollowing = user.followingIds ?? const <String>[];
    mutualFollowers = isOwn
        ? const []
        : [
            for (final followed in circle.visibleFollowing)
              if (profileFollowing.contains(followed.userId)) followed,
          ];
    thisWeek = CircleWeek.sessionsInWeek(
      user.userId,
      now,
      sessions,
      firstDayOfWeek,
    );
    final local = now.toLocal();
    final cutoff = DateTime(local.year, local.month, local.day - 12 * 7);
    trainingDays = {
      for (final session in sessions)
        if (!session.dateCreated.toLocal().isBefore(cutoff))
          _day(session.dateCreated),
    };
  }

  /// The profile.
  final UserModel user;

  /// The signed-in reader.
  final UserModel? viewer;

  /// The reader's own profile.
  final bool isOwn;

  /// What the follow button offers.
  final FollowState followState;

  /// The reader has blocked the profile.
  final bool isBlocked;

  /// A private profile the reader does not follow: the header, the counts
  /// and a lock message only.
  late final bool isLocked;

  /// Finished, non-rest workouts, newest first; none when locked.
  late final List<WorkoutSessionModel> sessions;

  /// People the reader follows whom the profile follows too.
  late final List<UserModel> mutualFollowers;

  /// This week's workouts.
  late final List<WorkoutSessionModel> thisWeek;

  /// Days with a workout in the last twelve weeks, local midnight.
  late final Set<DateTime> trainingDays;

  static DateTime _day(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Nobody follows an account they have blocked, or themselves.
  bool get showsFollowButton => !isOwn && !isBlocked;

  /// "Follows you": the profile's following list names the reader.
  bool get followsYou =>
      !isOwn && (user.followingIds?.contains(viewer?.userId) ?? false);

  /// Every finished workout, on the reader's own profile only: anyone
  /// else's is the newest 30.
  int? get workoutCount => isOwn ? sessions.length : null;

  /// The streak stamped on the newest workout that carries one, from two
  /// weeks on.
  int? get latestStreak {
    final weeks = sessions
        .map((session) => session.weekStreakCount)
        .nonNulls
        .firstOrNull;
    return weeks != null && weeks > 1 ? weeks : null;
  }

  /// Time trained this week.
  Duration get thisWeekDuration => thisWeek.fold(
    Duration.zero,
    (total, session) => total + (session.activeDuration ?? Duration.zero),
  );

  /// Volume lifted this week, in kilograms.
  double get thisWeekVolumeKg =>
      thisWeek.fold(0, (total, session) => total + session.loggedVolumeKg);
}
