import 'package:compound/social/logic/circle_week.dart';
import 'package:compound/social/logic/people.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel user(
  String id, {
  String? name,
  int? goal,
  List<String>? following,
  List<String>? blocked,
}) => UserModel(
  userId: id,
  displayName: name ?? id,
  firstName: name ?? id,
  weeklySessionGoal: goal,
  followingIds: following,
  blockedUserIds: blocked,
);

WorkoutSessionModel session(
  String id,
  String author,
  DateTime at, {
  bool ended = true,
  bool restDay = false,
  double? weightKg,
}) => WorkoutSessionModel(
  id: id,
  authorId: author,
  name: 'Session $id',
  dateCreated: at,
  dateModified: at,
  endedAt: ended ? at.add(const Duration(hours: 1)) : null,
  isRestDay: restDay,
  exercises: [
    if (weightKg != null)
      WorkoutExerciseModel(
        id: '$id-ex',
        authorId: author,
        templateId: 'bench',
        name: 'Bench',
        trackingMode: TrackingMode.weightReps,
        index: 0,
        sets: [
          WorkoutSetModel(
            id: '$id-set',
            authorId: author,
            index: 0,
            isWarmup: false,
            weightKg: weightKg,
            reps: 10,
            completedAt: at,
            dateCreated: at,
          ),
        ],
      ),
  ],
);

void main() {
  // Wednesday 14 October 2026, 6pm local; weeks start on Monday (1).
  final now = DateTime(2026, 10, 14, 18);
  const monday = 1;

  group('CircleWeek', () {
    test('progress is clamped and a goal of none is full', () {
      expect(CircleWeek.progress(1, 4), 0.25);
      expect(CircleWeek.progress(6, 3), 1);
      expect(CircleWeek.progress(0, 0), 1);
      expect(CircleWeek.remaining(5, 3), 0);
      expect(CircleWeek.remaining(1, 3), 2);
    });

    test('counts finished non-rest sessions in the week only', () {
      final sessions = [
        session('a', 'me', DateTime(2026, 10, 12, 9)),
        session('b', 'me', DateTime(2026, 10, 13, 9), restDay: true),
        session('c', 'me', DateTime(2026, 10, 13, 9), ended: false),
        session('d', 'me', DateTime(2026, 10, 11, 9)),
        session('e', 'you', DateTime(2026, 10, 13, 9)),
      ];
      expect(
        CircleWeek.sessionsInWeek('me', now, sessions, monday).map((s) => s.id),
        ['a'],
      );
    });

    test('volume counts completed working sets', () {
      final sessions = [
        session('a', 'me', DateTime(2026, 10, 12, 9), weightKg: 50),
      ];
      expect(CircleWeek.volumeKg('me', now, sessions, monday), 500);
    });

    test('knows the first and last days of the week', () {
      expect(CircleWeek.isFirstDayOfWeek(DateTime(2026, 10, 12), monday), true);
      expect(CircleWeek.isFirstDayOfWeek(now, monday), false);
      expect(CircleWeek.isLastDayOfWeek(DateTime(2026, 10, 18), monday), true);
      expect(CircleWeek.isLastDayOfWeek(now, monday), false);
    });

    group('members', () {
      final viewer = user('me', name: 'Me', goal: 2, blocked: ['blocked']);

      test('are empty without anyone followed', () {
        expect(
          CircleWeek.members(
            viewer: viewer,
            following: const [],
            sessions: const [],
            nudged: const {},
            now: now,
            firstDayOfWeek: monday,
          ),
          isEmpty,
        );
      });

      test('put those trained today first, then by name', () {
        final members = CircleWeek.members(
          viewer: viewer,
          following: [
            user('zed', name: 'Zed'),
            user('amy', name: 'Amy'),
            user('bob', name: 'Bob'),
            user('blocked', name: 'Blocked'),
            user('me', name: 'Me'),
          ],
          sessions: [session('z1', 'zed', DateTime(2026, 10, 14, 7))],
          nudged: const {'bob'},
          now: now,
          firstDayOfWeek: monday,
        );
        expect(members.map((m) => m.user.userId), ['zed', 'amy', 'bob', 'me']);
        final byId = {for (final m in members) m.user.userId: m};
        expect(byId['zed']!.trainedToday, isTrue);
        expect(byId['zed']!.canNudge, isFalse);
        expect(byId['amy']!.canNudge, isTrue);
        expect(byId['bob']!.canNudge, isFalse);
        expect(byId['me']!.canNudge, isFalse);
        expect(byId['me']!.isCurrentUser, isTrue);
        expect(byId['me']!.weeklyGoal, 2);
        expect(byId['zed']!.sessionsThisWeek, 1);
        expect(byId['zed']!.progress, closeTo(1 / 3, 1e-9));
        expect(byId['me']!.sessionsToGo, isNull);
      });

      test('show what the reader still owes on the last day', () {
        final members = CircleWeek.members(
          viewer: viewer,
          following: [user('amy')],
          sessions: const [],
          nudged: const {},
          now: DateTime(2026, 10, 18, 9),
          firstDayOfWeek: monday,
        );
        final me = members.firstWhere((m) => m.isCurrentUser);
        expect(me.sessionsToGo, 2);
      });
    });

    test('ranks by sessions, then volume, then name', () {
      final standings = CircleWeek.standings(
        users: [
          user('b', name: 'B'),
          user('a', name: 'A'),
          user('c'),
        ],
        sessions: [
          session('1', 'c', DateTime(2026, 10, 12, 9)),
          session('2', 'c', DateTime(2026, 10, 13, 9)),
          session('3', 'b', DateTime(2026, 10, 12, 9), weightKg: 10),
          session('4', 'a', DateTime(2026, 10, 12, 9), weightKg: 5),
        ],
        now: now,
        firstDayOfWeek: monday,
      );
      expect(standings.map((s) => s.user.userId), ['c', 'b', 'a']);
      expect(standings.first.sessions, 2);
      expect(standings.first.goal, 3);
      // A tie on sessions shares its place; volume only orders the rows.
      expect(
        [for (final s in standings) CircleWeek.place(standings, s)],
        [1, 2, 2],
      );
    });

    test('gives no place without a session', () {
      final standings = CircleWeek.standings(
        users: [user('a'), user('b')],
        sessions: [session('1', 'a', DateTime(2026, 10, 12, 9))],
        now: now,
        firstDayOfWeek: monday,
      );
      expect(
        [for (final s in standings) CircleWeek.place(standings, s)],
        [1, null],
      );
    });

    group('summary', () {
      final reader = user('me', goal: 4);
      final mondayMorning = DateTime(2026, 10, 12, 8);
      final lastWeek = [
        session('1', 'me', DateTime(2026, 10, 6, 9)),
        session('2', 'you', DateTime(2026, 10, 7, 9)),
        session('3', 'you', DateTime(2026, 10, 8, 9)),
      ];

      test('recaps last week on Monday', () {
        final summary = CircleWeek.summary(
          reader: reader,
          circle: [reader, user('you')],
          sessions: lastWeek,
          now: mondayMorning,
          firstDayOfWeek: monday,
        );
        expect(summary?.ownSessions, 1);
        expect(summary?.ownGoal, 4);
        expect(summary?.circleSessions, 3);
        expect(summary?.weekStart, DateTime(2026, 10, 12));
      });

      test('is gone on other days and once dismissed', () {
        expect(
          CircleWeek.summary(
            reader: reader,
            circle: [reader],
            sessions: lastWeek,
            now: now,
            firstDayOfWeek: monday,
          ),
          isNull,
        );
        expect(
          CircleWeek.summary(
            reader: reader,
            circle: [reader],
            sessions: lastWeek,
            now: mondayMorning,
            firstDayOfWeek: monday,
            dismissedWeek: DateTime(2026, 10, 12),
          ),
          isNull,
        );
      });
    });
  });

  group('people', () {
    test('following wins over a request', () {
      final viewer = user('me', following: ['a']);
      expect(followStateOf(viewer, {'a', 'b'}, 'a'), FollowState.following);
      expect(followStateOf(viewer, {'b'}, 'b'), FollowState.requested);
      expect(followStateOf(null, const {}, 'c'), FollowState.follow);
    });

    test('names fall back as Swift does', () {
      expect(commonNameOf(const UserModel(userId: 'x', firstName: 'Al')), 'Al');
      expect(
        commonNameOf(const UserModel(userId: 'x', displayName: 'Al B')),
        'Al B',
      );
      expect(
        listNameOf(const UserModel(userId: 'x', firstName: 'A', lastName: 'B')),
        'A B',
      );
      expect(commonNameOf(const UserModel(userId: 'x')), isNull);
    });
  });
}
