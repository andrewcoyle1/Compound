import 'package:bloc_test/bloc_test.dart';
import 'package:compound/challenges/challenges.dart';
import 'package:compound/challenges/cubit/challenge_detail_cubit.dart';
import 'package:compound/challenges/cubit/create_challenge_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_repository/social_repository.dart';

import '../helpers/helpers.dart';

class _MockSocial extends Mock implements SocialRepository;

void main() {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day, 9, 30);
  const me = UserModel(
    userId: 'me',
    submittedFirstName: 'Me',
    blockedUserIds: ['blocked'],
  );
  const following = [
    UserModel(
      userId: 'mutual',
      submittedFirstName: 'Mutual',
      followingIds: ['me'],
    ),
    UserModel(
      userId: 'oneway',
      submittedFirstName: 'One Way',
      followingIds: [],
    ),
    UserModel(
      userId: 'blocked',
      submittedFirstName: 'Blocked',
      followingIds: ['me'],
    ),
  ];
  late _MockSocial social;
  late AnalyticsRecorder analytics;

  setUpAll(() {
    registerFallbackValue(
      ChallengeModel(
        id: 'x',
        ownerId: 'x',
        title: 'x',
        targetSessions: 1,
        startsAt: start,
        endsAt: start,
        memberIds: const [],
        dateCreated: start,
      ),
    );
    registerFallbackValue(const UserModel(userId: 'x'));
  });

  setUp(() {
    social = _MockSocial();
    analytics = AnalyticsRecorder();
  });

  group(CreateChallengeCubit, () {
    CreateChallengeCubit build({List<UserModel> people = following}) =>
        CreateChallengeCubit(
          social: social,
          analytics: analytics,
          viewer: me,
          following: people,
          now: () => start,
          newId: () => 'new-challenge',
        );

    test('offers only unblocked mutuals', () {
      expect(
        [for (final user in build().state.candidates) user.userId],
        ['mutual'],
      );
    });

    test('needs a name and at least one member', () {
      final cubit = build();
      expect(cubit.state.canCreate, isFalse);
      expect(cubit.state.validation, ChallengeValidation.noName);

      cubit.titleChanged('   ');
      expect(cubit.state.validation, ChallengeValidation.noName);

      cubit.titleChanged('October');
      expect(cubit.state.validation, ChallengeValidation.noMembers);

      cubit.candidatePressed('mutual');
      expect(cubit.state.validation, isNull);
      expect(cubit.state.canCreate, isTrue);

      cubit.candidatePressed('mutual');
      expect(cubit.state.canCreate, isFalse, reason: 'tapping again unticks');
    });

    test('preselects the only candidate without counting it as a change', () {
      final cubit = build()..appeared();
      expect(cubit.state.selectedIds, {'mutual'});
      expect(cubit.state.hasUnsavedChanges, isFalse);

      cubit
        ..candidatePressed('mutual')
        ..appeared();
      expect(
        cubit.state.selectedIds,
        isEmpty,
        reason: 'a later appear does not re-tick',
      );
      expect(analytics.names, contains('CreateChallengeView_Appear'));
    });

    test('preselects no one when there is a choice', () {
      final cubit = build(
        people: [
          ...following,
          const UserModel(
            userId: 'mutual2',
            submittedFirstName: 'Mutual 2',
            followingIds: ['me'],
          ),
        ],
      )..appeared();
      expect(cubit.state.selectedIds, isEmpty);
    });

    test('rejects a long name, an out-of-range target and an unoffered '
        'duration', () {
      final cubit = build()
        ..candidatePressed('mutual')
        ..titleChanged('a' * (challengeTitleMaxLength + 1));
      expect(cubit.state.validation, ChallengeValidation.nameTooLong);

      cubit
        ..titleChanged('Fine')
        ..targetChanged(0);
      expect(cubit.state.validation, ChallengeValidation.targetOutOfRange);

      cubit
        ..targetChanged(10)
        ..durationChanged(9);
      expect(cubit.state.validation, ChallengeValidation.noDuration);

      cubit.durationChanged(30);
      expect(cubit.state.canCreate, isTrue);
    });

    test('a typed title counts as unsaved', () {
      final cubit = build()..titleChanged('x');
      expect(cubit.state.hasUnsavedChanges, isTrue);
    });

    blocTest<CreateChallengeCubit, CreateChallengeState>(
      'sends the trimmed title and the selected members, owner first',
      setUp: () =>
          when(() => social.createChallenge(any())).thenAnswer((_) async {}),
      build: build,
      act: (cubit) =>
          (cubit
                ..titleChanged('  October Grind ')
                ..targetChanged(12)
                ..durationChanged(30)
                ..candidatePressed('mutual'))
              .createPressed(),
      skip: 4,
      expect: () => [
        isA<CreateChallengeState>().having(
          (state) => state.status,
          'status',
          CreateChallengeStatus.saving,
        ),
        isA<CreateChallengeState>().having(
          (state) => state.status,
          'status',
          CreateChallengeStatus.created,
        ),
      ],
      verify: (cubit) {
        final created =
            verify(() => social.createChallenge(captureAny())).captured.single
                as ChallengeModel;
        expect(created.id, 'new-challenge');
        expect(created.title, 'October Grind');
        expect(created.targetSessions, 12);
        expect(created.ownerId, 'me');
        expect(created.memberIds, ['me', 'mutual']);
        expect(created.startsAt, start);
        expect(
          created.endsAt,
          DateTime(start.year, start.month, start.day + 30, 9, 30),
        );
        expect(cubit.state.created, created);
        expect(analytics.parameters('CreateChallengeView_Create_Start'), {
          'target_sessions': 12,
          'duration_days': 30,
          'member_count': 1,
        });
        expect(analytics.names, contains('CreateChallengeView_Create_Success'));
      },
    );

    test('a failed create says so and allows a retry', () async {
      when(() => social.createChallenge(any())).thenThrow(StateError('x'));
      final cubit = build()
        ..titleChanged('October')
        ..candidatePressed('mutual');
      await cubit.createPressed();
      expect(cubit.state.status, CreateChallengeStatus.failed);
      expect(cubit.state.failureId, 1);
      expect(cubit.state.canCreate, isTrue);
      expect(analytics.names, contains('CreateChallengeView_Create_Fail'));

      cubit.disappeared();
      expect(analytics.names.last, 'CreateChallengeView_Disappear');
    });
  });

  group(ChallengeDetailCubit, () {
    final challenge = ChallengeModel(
      id: 'c1',
      ownerId: 'me',
      title: 'Grind',
      targetSessions: 8,
      startsAt: start,
      endsAt: start.add(const Duration(days: 5)),
      memberIds: const ['me', 'amy', 'zed', 'stranger'],
      dateCreated: start,
    );
    const amy = UserModel(userId: 'amy', submittedFirstName: 'Amy');
    const zed = UserModel(userId: 'zed', submittedFirstName: 'Zed');

    ChallengeDetailCubit build({ChallengeModel? opened}) =>
        ChallengeDetailCubit(
          social: social,
          analytics: analytics,
          viewer: me,
          challengeId: 'c1',
          following: const [amy, zed],
          challenge: opened,
          progress: const {'me': 2, 'amy': 4},
        );

    // ChallengesPresenterTests.testDetailRingShowsTheReadersSessions
    test('starts from the counts held, the reader among them', () {
      final cubit = build(opened: challenge);
      expect(cubit.state.progress['me'], 2);
      expect(
        ChallengeStandings.ringProgress(
          sessions: cubit.state.progress['me']!,
          target: challenge.targetSessions,
        ),
        0.25,
      );
    });

    test(
      'reads the standings, then fetches the members it cannot name',
      () async {
        when(() => social.challengeProgress('c1'))
            .thenAnswer((_) async => {'zed': 3, 'amy': 3, 'me': 5});
        when(() => social.users(['stranger'], viewer: me)).thenAnswer(
          (_) async => const [
            UserModel(userId: 'stranger', submittedFirstName: 'Stranger'),
          ],
        );
        final cubit = build(opened: challenge)..appeared();
        await cubit.load();
        final standings = cubit.state.standings(challenge);
        expect(
          [for (final entry in standings) entry.userId],
          ['me', 'amy', 'zed', 'stranger'],
        );
        expect(standings.last.name, 'Stranger');
        expect(analytics.names, ['ChallengeDetailView_Appear']);
      },
    );

    test('a failed refresh keeps what it had, and an unfetchable member '
        'stays unnamed', () async {
      when(() => social.challengeProgress('c1')).thenThrow(StateError('x'));
      when(() => social.users(any(), viewer: any(named: 'viewer')))
          .thenThrow(StateError('x'));
      final cubit = build(opened: challenge);
      await cubit.load();
      expect(cubit.state.progress, {'me': 2, 'amy': 4});
      expect(
        cubit.state
            .standings(challenge)
            .firstWhere((entry) => entry.userId == 'stranger')
            .name,
        isNull,
      );
      expect(analytics.names, [
        'ChallengeDetailView_RefreshProgress_Fail',
        'ChallengeDetailView_LoadMember_Fail',
      ]);
    });

    test('opened by id, it reads the challenge first', () async {
      when(() => social.challenge('c1')).thenAnswer((_) async => challenge);
      when(() => social.challengeProgress('c1')).thenAnswer((_) async => {});
      when(() => social.users(any(), viewer: any(named: 'viewer')))
          .thenAnswer((_) async => const []);
      final cubit = build();
      await cubit.load();
      expect(cubit.state.challenge, challenge);
      expect(cubit.state.notFound, isFalse);
    });

    test('a challenge that cannot be read is not found', () async {
      when(() => social.challenge('c1')).thenAnswer((_) async => null);
      final cubit = build();
      await cubit.load();
      expect(cubit.state.notFound, isTrue);

      when(() => social.challenge('c1')).thenThrow(StateError('x'));
      final failing = build();
      await failing.load();
      expect(failing.state.notFound, isTrue);
    });

    test('leaves, and says so when leaving fails', () async {
      when(() => social.leaveChallenge('c1', userId: 'me'))
          .thenAnswer((_) async {});
      final cubit = build(opened: challenge);
      await cubit.leave();
      expect(cubit.state.leaveStatus, ChallengeLeaveStatus.left);
      expect(analytics.names, [
        'ChallengeDetailView_Leave_Start',
        'ChallengeDetailView_Leave_Success',
      ]);

      when(() => social.leaveChallenge('c1', userId: 'me'))
          .thenThrow(StateError('x'));
      final failing = build(opened: challenge);
      await failing.leave();
      expect(failing.state.leaveStatus, ChallengeLeaveStatus.failed);
      expect(failing.state.failureId, 1);
      expect(analytics.names.last, 'ChallengeDetailView_Leave_Fail');

      failing.disappeared();
      expect(analytics.names.last, 'ChallengeDetailView_Disappear');
    });
  });

  group(ChallengesCubit, () {
    final first = ChallengeModel(
      id: 'a',
      ownerId: 'me',
      title: 'A',
      targetSessions: 3,
      startsAt: start,
      endsAt: start.add(const Duration(days: 9)),
      memberIds: const ['me'],
      dateCreated: start,
    );
    final second = ChallengeModel(
      id: 'b',
      ownerId: 'me',
      title: 'B',
      targetSessions: 3,
      startsAt: start,
      endsAt: start.add(const Duration(days: 3)),
      memberIds: const ['me'],
      dateCreated: start,
    );

    test("reads the viewer's challenges and their standings", () async {
      when(() => social.challenges('me')).thenAnswer((_) async => [first]);
      when(() => social.challengeProgress('a'))
          .thenAnswer((_) async => {'me': 1});
      final cubit = ChallengesCubit(social: social, analytics: analytics);
      await cubit.refresh();
      expect(cubit.state.challenges, isEmpty, reason: 'no one signed in');

      cubit.viewerChanged('me');
      await cubit.refresh();
      expect(cubit.state.challenges, [first]);
      expect(cubit.state.progress, {
        'a': {'me': 1},
      });

      cubit
        ..added(second)
        ..progressRead('b', {'me': 2});
      expect(cubit.state.challenges, [second, first]);
      expect(cubit.state.challenge('b'), second);
      expect(cubit.state.progress['b'], {'me': 2});

      cubit.left('a');
      expect(cubit.state.challenges, [second]);
      expect(cubit.state.progress.containsKey('a'), isFalse);

      cubit.viewerChanged('someone-else');
      expect(cubit.state.challenges, isEmpty);
    });

    test('a failed refresh keeps what it had', () async {
      when(() => social.challenges('me')).thenThrow(StateError('x'));
      final cubit = ChallengesCubit(social: social, analytics: analytics)
        ..viewerChanged('me')
        ..added(first);
      await cubit.refresh();
      expect(cubit.state.challenges, [first]);
      expect(analytics.names, ['SocialView_LoadChallenges_Fail']);
    });
  });
}
