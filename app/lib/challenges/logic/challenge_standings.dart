import 'package:compound/social/logic/people.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

/// The lengths the create screen offers, in days (`ChallengeModel.durations`).
const challengeDurations = [7, 14, 30];

/// The longest title, in characters; the rules allow 60.
const challengeTitleMaxLength = 60;

/// The lowest and highest session target, as the rules allow.
const challengeTargetMin = 1;

/// See [challengeTargetMin].
const challengeTargetMax = 100;

/// One member's place in a challenge (`ChallengeStandings.Entry`). [name] is
/// null for a member the reader cannot name, shown as "Member".
final class const ChallengeStanding({
  required final String userId,
  required final String? name,
  required final String? imageUrl,
  required final int sessions,
  required final bool isComplete,
}) extends Equatable {
  @override
  List<Object?> get props => [userId, name, imageUrl, sessions, isComplete];
}

/// The pure part of a challenge's display, shared by the Social card and
/// the detail screen so the two never disagree (`ChallengeStandings`).
abstract final class ChallengeStandings {
  /// Every member, most sessions first; ties by name so the order is
  /// stable. A member with no count has none.
  static List<ChallengeStanding> entries(
    ChallengeModel challenge, {
    required Map<String, int> progress,
    required Map<String, UserModel> users,
  }) {
    final entries = [
      for (final memberId in challenge.memberIds)
        () {
          final user = users[memberId];
          final sessions = progress[memberId] ?? 0;
          return ChallengeStanding(
            userId: memberId,
            name: user == null ? null : commonNameOf(user),
            imageUrl: user == null ? null : profileImageOf(user),
            sessions: sessions,
            isComplete: sessions >= challenge.targetSessions,
          );
        }(),
    ];
    return entries..sort((a, b) {
      if (a.sessions != b.sessions) return b.sessions.compareTo(a.sessions);
      return (a.name ?? 'Member').toLowerCase().compareTo(
        (b.name ?? 'Member').toLowerCase(),
      );
    });
  }

  /// How full a member's ring is, 0 to 1.
  static double ringProgress({required int sessions, required int target}) {
    if (target <= 0) return 0;
    return (sessions / target).clamp(0, 1).toDouble();
  }

  /// Whole days left, counting today; zero once [challenge] has ended
  /// (`ChallengeModel.daysLeft`).
  static int daysLeft(ChallengeModel challenge, DateTime now) {
    if (!now.isBefore(challenge.endsAt)) return 0;
    final start = _day(now);
    final end = _day(challenge.endsAt);
    // Rounded: a day across a clock change is 23 or 25 hours.
    final days = (end.difference(start).inHours / 24).round();
    return days < 1 ? 1 : days;
  }

  /// Whether [challenge] runs at [now].
  static bool isActive(ChallengeModel challenge, DateTime now) =>
      !challenge.startsAt.isAfter(now) && now.isBefore(challenge.endsAt);

  static DateTime _day(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

/// A running challenge on Social (`SocialPresenter.ChallengeCard`).
final class const ChallengeCard({
  required final ChallengeModel challenge,
  required final int daysLeft,
  required final int mySessions,
  required final List<ChallengeStanding> topThree,
}) extends Equatable {
  @override
  List<Object?> get props => [challenge, daysLeft, mySessions, topThree];
}

/// Running challenges, soonest to end first, each with the reader's count
/// and the top three; ended ones are left to the detail screen
/// (`SocialPresenter.challengeCards`).
List<ChallengeCard> challengeCards(
  List<ChallengeModel> challenges, {
  required Map<String, Map<String, int>> progress,
  required Map<String, UserModel> users,
  required String? readerId,
  required DateTime now,
}) => [
  for (final challenge in challenges)
    if (challenge.endsAt.isAfter(now))
      ChallengeCard(
        challenge: challenge,
        daysLeft: ChallengeStandings.daysLeft(challenge, now),
        mySessions: progress[challenge.id]?[readerId] ?? 0,
        topThree: ChallengeStandings.entries(
          challenge,
          progress: progress[challenge.id] ?? const {},
          users: users,
        ).take(3).toList(),
      ),
];
