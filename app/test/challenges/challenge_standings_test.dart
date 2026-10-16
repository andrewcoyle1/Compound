import 'package:compound/challenges/challenges.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime.now();
  DateTime day(int offset, [int hour = 12]) =>
      DateTime(today.year, today.month, today.day + offset, hour);

  ChallengeModel challenge({
    String id = 'c1',
    int target = 4,
    List<String> members = const ['me', 'amy', 'zed', 'stranger'],
    DateTime? startsAt,
    DateTime? endsAt,
  }) => ChallengeModel(
    id: id,
    ownerId: 'me',
    title: 'Grind',
    targetSessions: target,
    startsAt: startsAt ?? day(-1),
    endsAt: endsAt ?? day(5),
    memberIds: members,
    dateCreated: day(-1),
  );

  const users = {
    'me': UserModel(userId: 'me', submittedFirstName: 'Me'),
    'amy': UserModel(userId: 'amy', submittedFirstName: 'Amy'),
    'zed': UserModel(userId: 'zed', submittedFirstName: 'Zed'),
  };

  group(ChallengeStandings, () {
    // ChallengesPresenterTests.testStandingsOrder
    test('ranks by sessions then name, with absent members at zero', () {
      final standings = ChallengeStandings.entries(
        challenge(),
        progress: {'zed': 3, 'amy': 3, 'me': 5},
        users: {
          ...users,
          'stranger': const UserModel(
            userId: 'stranger',
            submittedFirstName: 'Stranger',
          ),
        },
      );
      expect(
        [for (final entry in standings) entry.userId],
        ['me', 'amy', 'zed', 'stranger'],
      );
      expect([for (final entry in standings) entry.sessions], [5, 3, 3, 0]);
      expect(
        [for (final entry in standings) entry.isComplete],
        [true, false, false, false],
      );
      expect(standings.last.name, 'Stranger');
    });

    // ChallengesPresenterTests.testUnfetchableMemberStillRanks
    test('a member who cannot be named still ranks, with no name', () {
      final standings = ChallengeStandings.entries(
        challenge(),
        progress: const {},
        users: users,
      );
      expect(standings, hasLength(4));
      expect(
        standings.firstWhere((entry) => entry.userId == 'stranger').name,
        isNull,
      );
    });

    // ChallengesPresenterTests.testRingProgress
    test('the ring fills in proportion and stops at full', () {
      expect(ChallengeStandings.ringProgress(sessions: 0, target: 4), 0);
      expect(ChallengeStandings.ringProgress(sessions: 1, target: 4), 0.25);
      expect(ChallengeStandings.ringProgress(sessions: 4, target: 4), 1);
      expect(ChallengeStandings.ringProgress(sessions: 9, target: 4), 1);
      expect(ChallengeStandings.ringProgress(sessions: 3, target: 0), 0);
    });

    // ChallengesPresenterTests.testDaysLeft
    test('days left counts today and reads zero afterwards', () {
      final now = DateTime.now();
      expect(
        ChallengeStandings.daysLeft(challenge(), now),
        greaterThanOrEqualTo(5),
      );
      expect(ChallengeStandings.isActive(challenge(), now), isTrue);
      final ended = challenge(startsAt: day(-10), endsAt: day(-1));
      expect(ChallengeStandings.daysLeft(ended, now), 0);
      expect(ChallengeStandings.isActive(ended, now), isFalse);
      // Ending later today is still a day.
      final tonight = challenge(endsAt: now.add(const Duration(minutes: 1)));
      expect(ChallengeStandings.daysLeft(tonight, now), 1);
    });
  });

  // ChallengesPresenterTests.testTodayCard
  test('a card shows my sessions and the top three; ended ones drop off', () {
    final running = challenge();
    final ended = challenge(
      id: 'old',
      target: 1,
      members: const ['me'],
      startsAt: day(-10),
      endsAt: day(-1),
    );
    final cards = challengeCards(
      [running, ended],
      progress: {
        'c1': {'amy': 4, 'me': 2, 'zed': 3, 'stranger': 1},
      },
      users: users,
      readerId: 'me',
      now: DateTime.now(),
    );
    expect([for (final card in cards) card.challenge.id], ['c1']);
    expect(cards.single.mySessions, 2);
    expect(
      [for (final entry in cards.single.topThree) entry.userId],
      ['amy', 'zed', 'me'],
    );
    expect(cards.single.daysLeft, greaterThanOrEqualTo(5));
  });
}
