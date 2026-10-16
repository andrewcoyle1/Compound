import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/settings/account/username/edit_username_bloc.dart';
import 'package:compound/social/comments/comment_thread.dart';
import 'package:compound/social/comments/comments_cubit.dart';
import 'package:compound/social/feed/session_like_cubit.dart';
import 'package:compound/social/followers/people_list_cubit.dart';
import 'package:compound/social/profile/social_profile_cubit.dart';
import 'package:compound/social/search/people_search_bloc.dart';
import 'package:compound/social/search/social_cubit.dart';
import 'package:compound/social/weekly_goal/weekly_goal_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_repository/social_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

class _MockAnalytics extends Mock implements AnalyticsRepository;

class _MockSocial extends Mock implements SocialRepository;

class _MockUsers extends Mock implements UserRepository;

class _FakeEvent extends Fake implements LoggableEvent;

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);
  late UserModel viewer;
  late InMemoryUserRepository users;
  late SocialRepository social;
  late _MockSocial failing;
  late AnalyticsRepository analytics;
  late List<String> events;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(const UserModel(userId: 'x'));
    registerFallbackValue(
      WorkoutSessionComment(
        id: 'x',
        sessionId: 's',
        sessionAuthorId: 'a',
        authorId: 'a',
        text: 't',
        dateCreated: DateTime(2026),
      ),
    );
  });

  setUp(() async {
    viewer = sampleUser(now: now);
    users = InMemoryUserRepository(users: {sampleUserId: viewer});
    social = await inMemorySocialRepository(users: users, now: now);
    failing = _MockSocial();
    events = [];
    analytics = _MockAnalytics();
    void record(Invocation call) =>
        events.add((call.positionalArguments.first as LoggableEvent).eventName);
    when(() => analytics.trackEvent(any())).thenAnswer(record);
    when(() => analytics.trackScreenView(any())).thenAnswer(record);
  });

  // The sample world: Maya's newest session has Charlie's comment and the
  // viewer's reply; the viewer's own newest has Maya's.
  const mayaSession = 'user1-sample-session-push-b';

  group(CommentsCubit, () {
    CommentsCubit build([SocialRepository? with_]) => CommentsCubit(
      social: with_ ?? social,
      analytics: analytics,
      sessionId: mayaSession,
      sessionAuthorId: 'user1',
      now: () => now,
      newId: () => 'new-comment',
    );

    test('loads the thread, then the author for mentions', () async {
      final cubit = build()..appeared();
      await cubit.load(viewer: viewer, following: const []);
      expect(cubit.state.status, CommentsStatus.loaded);
      expect(cubit.state.comments.map((c) => c.id), [
        'sample-comment-1',
        'sample-comment-2',
      ]);
      expect(cubit.state.isReply(cubit.state.comments.last), isTrue);
      expect(cubit.state.sessionAuthor?.userId, 'user1');
      cubit.disappeared();
      expect(events, ['CommentsView_Appear', 'CommentsView_Disappear']);
    });

    test('replies, mentions, posts and deletes', () async {
      final cubit = build();
      await cubit.load(viewer: viewer, following: const []);
      cubit
        ..replyPressed(cubit.state.comments.last)
        ..draftChanged('Thanks @ma');
      expect(cubit.state.replyingTo?.id, 'sample-comment-1');
      const maya = MentionCandidate(
        id: 'user1',
        fullName: 'Maya Chen',
        username: 'maya.chen',
      );
      cubit
        ..mentionPressed(maya)
        ..mentionPressed(maya);
      expect(cubit.state.draft, 'Thanks @maya.chen ');
      expect(cubit.state.draftMentions, [maya]);
      await cubit.sendPressed(viewer);
      final posted = cubit.state.comments.firstWhere(
        (c) => c.id == 'new-comment',
      );
      expect(posted.parentId, 'sample-comment-1');
      expect(posted.mentionedUserIds, ['user1']);
      expect(cubit.state.draft, isEmpty);
      expect(cubit.state.replyingTo, isNull);

      expect(await cubit.likePressed(posted, viewer.userId), isTrue);
      expect(
        cubit.state.comments
            .firstWhere((c) => c.id == 'new-comment')
            .likedByUserIds,
        [viewer.userId],
      );
      await cubit.deleteConfirmed(posted);
      expect(cubit.state.comments.map((c) => c.id), isNot(contains(posted.id)));
      expect((await social.comments(mayaSession)).map((c) => c.id), [
        isNot('new-comment'),
        isNot('new-comment'),
      ]);
      cubit.cancelReplyPressed();
      await cubit.sendPressed(viewer);
      expect(events, contains('CommentsView_DeleteComment_Success'));
    });

    test('puts everything back when writes fail', () async {
      when(() => failing.comments(any())).thenAnswer(
        (_) async => [
          WorkoutSessionComment(
            id: 'c',
            sessionId: mayaSession,
            sessionAuthorId: 'user1',
            authorId: 'user1',
            authorName: 'Maya Chen',
            text: 'Hi',
            dateCreated: now,
          ),
        ],
      );
      when(() => failing.addComment(any())).thenThrow(Exception('denied'));
      when(
        () => failing.setCommentLike(
          any(),
          userId: any(named: 'userId'),
          liked: any(named: 'liked'),
        ),
      ).thenThrow(Exception('denied'));
      when(() => failing.deleteComment(any())).thenThrow(Exception('denied'));
      final cubit = build(failing);
      await cubit.load(viewer: viewer, following: const []);
      final comment = cubit.state.comments.single;

      cubit.draftChanged('  Hello  ');
      await cubit.sendPressed(viewer);
      expect(cubit.state.draft, 'Hello');
      expect(cubit.state.comments, [comment]);
      expect(cubit.state.notice, CommentsNotice.postFailed);

      expect(await cubit.likePressed(comment, viewer.userId), isFalse);
      expect(cubit.state.comments.single.likedByUserIds, isEmpty);
      await cubit.deleteConfirmed(comment);
      expect(cubit.state.comments, [comment]);
      expect(cubit.state.notice, CommentsNotice.deleteFailed);
      expect(cubit.state.noticeId, 2);
    });

    test('says when the thread cannot be read', () async {
      when(() => failing.comments(any())).thenThrow(Exception('offline'));
      when(() => failing.users(any(), viewer: any(named: 'viewer')))
          .thenThrow(Exception('offline'));
      final cubit = build(failing);
      await cubit.load(viewer: viewer, following: const []);
      expect(cubit.state.status, CommentsStatus.failed);
      expect(events, [
        'CommentsView_LoadComments_Fail',
        'CommentsView_LoadAuthor_Fail',
      ]);
    });
  });

  group(SessionLikeCubit, () {
    late WorkoutSessionModel session;

    setUp(() async {
      session = (await social.sessionsByAuthor('user1')).first;
    });

    test('likes and unlikes', () async {
      final cubit = SessionLikeCubit(
        social: social,
        analytics: analytics,
        session: session,
        viewerId: viewer.userId,
      );
      expect(cubit.state, const SessionLikeState(isLiked: true, count: 1));
      expect(await cubit.toggled(viewer), isTrue);
      expect(cubit.state, const SessionLikeState(isLiked: false, count: 0));
      expect(await cubit.toggled(viewer), isTrue);
      expect(cubit.state, const SessionLikeState(isLiked: true, count: 1));
    });

    test('flips back when the write fails', () async {
      when(
        () => failing.unlikeSession(
          any(),
          authorId: any(named: 'authorId'),
          viewer: any(named: 'viewer'),
        ),
      ).thenThrow(Exception('denied'));
      final cubit = SessionLikeCubit(
        social: failing,
        analytics: analytics,
        session: session,
        viewerId: viewer.userId,
      );
      expect(await cubit.toggled(viewer), isFalse);
      expect(cubit.state, const SessionLikeState(isLiked: true, count: 1));
      expect(events.last, 'WorkoutSessionRow_Unlike_Fail');
    });
  });

  group(PeopleListCubit, () {
    blocTest<PeopleListCubit, PeopleListState>(
      'removes a follower through the function',
      build: () => PeopleListCubit(social: social, analytics: analytics),
      act: (cubit) => cubit.removeConfirmed('user3'),
      expect: () => [
        const PeopleListState(removing: true),
        const PeopleListState(removedIds: {'user3'}),
      ],
    );

    blocTest<PeopleListCubit, PeopleListState>(
      'says when removing failed',
      setUp: () =>
          when(() => failing.removeFollower(any()))
              .thenThrow(Exception('offline')),
      build: () => PeopleListCubit(social: failing, analytics: analytics),
      act: (cubit) {
        cubit
          ..appeared()
          ..disappeared();
        return cubit.removeConfirmed('user3');
      },
      skip: 1,
      expect: () => [const PeopleListState(failureId: 1)],
      verify: (_) => expect(events, [
        'FollowersListView_Appear',
        'FollowersListView_Disappear',
        'FollowersListView_RemoveFollower',
        'FollowersListView_RemoveFollower_Start',
        'FollowersListView_RemoveFollower_Fail',
      ]),
    );
  });

  group(WeeklyGoalCubit, () {
    blocTest<WeeklyGoalCubit, WeeklyGoalState>(
      'saves the goal picked, clamped',
      build: () => WeeklyGoalCubit(
        users: users,
        analytics: analytics,
        uid: sampleUserId,
        savedGoal: null,
      ),
      act: (cubit) => cubit.goalSelected(9),
      expect: () => [
        const WeeklyGoalState(selected: 7, status: WeeklyGoalStatus.saving),
        const WeeklyGoalState(selected: 7, status: WeeklyGoalStatus.saved),
      ],
      verify: (_) async => expect(
        (await users.watchUser(sampleUserId).first)!.weeklySessionGoal,
        7,
      ),
    );

    blocTest<WeeklyGoalCubit, WeeklyGoalState>(
      'goes back to the saved goal when saving fails',
      build: () {
        final broken = _MockUsers();
        when(() => broken.updateUserFields(any(), any()))
            .thenThrow(Exception('offline'));
        return WeeklyGoalCubit(
          users: broken,
          analytics: analytics,
          uid: sampleUserId,
          savedGoal: 3,
        );
      },
      act: (cubit) => cubit.goalSelected(5),
      skip: 1,
      expect: () => [
        const WeeklyGoalState(
          selected: 3,
          status: WeeklyGoalStatus.failed,
          failureId: 1,
        ),
      ],
    );
  });

  group(EditUsernameBloc, () {
    EditUsernameBloc build([SocialRepository? with_]) => EditUsernameBloc(
      social: with_ ?? social,
      analytics: analytics,
      current: viewer.username,
      debounce: Duration.zero,
    );

    blocTest<EditUsernameBloc, EditUsernameState>(
      'validates, then checks availability',
      build: build,
      act: (bloc) async {
        bloc.add(EditUsernameTextChanged('', viewer));
        await pumpEventQueue();
        bloc.add(EditUsernameTextChanged('@Alice.Cooper', viewer));
        await pumpEventQueue();
        bloc.add(EditUsernameTextChanged('ab', viewer));
        await pumpEventQueue();
        bloc.add(EditUsernameTextChanged('charlie.c', viewer));
        await pumpEventQueue();
        bloc.add(EditUsernameTextChanged('alice_new', viewer));
        await pumpEventQueue();
      },
      expect: () => [
        const EditUsernameState(),
        const EditUsernameState(
          text: 'alice.cooper',
          status: UsernameStatus.current,
        ),
        const EditUsernameState(
          text: 'ab',
          status: UsernameStatus.invalid,
          validation: UsernameValidation.tooShort,
        ),
        const EditUsernameState(
          text: 'charlie.c',
          status: UsernameStatus.checking,
          validation: UsernameValidation.tooShort,
        ),
        const EditUsernameState(
          text: 'charlie.c',
          status: UsernameStatus.taken,
          validation: UsernameValidation.tooShort,
        ),
        const EditUsernameState(
          text: 'alice_new',
          status: UsernameStatus.checking,
          validation: UsernameValidation.tooShort,
        ),
        const EditUsernameState(
          text: 'alice_new',
          status: UsernameStatus.available,
          validation: UsernameValidation.tooShort,
        ),
      ],
    );

    test('claims a free handle', () async {
      final bloc = build()..add(EditUsernameTextChanged('alice_new', viewer));
      await bloc.stream.firstWhere((s) => s.canSave);
      bloc.add(EditUsernameSavePressed(viewer));
      await bloc.stream.firstWhere((s) => s.saved);
      expect(
        (await users.watchUser(sampleUserId).first)!.username,
        'alice_new',
      );
      bloc
        ..appeared()
        ..disappeared();
      expect(events, contains('EditUsernameView_Save_Success'));
      await bloc.close();
    });

    test('reports a handle taken meanwhile, and other failures', () async {
      when(
        () => failing.isUsernameAvailable(any(), viewer: any(named: 'viewer')),
      ).thenAnswer((_) async => true);
      when(() => failing.claimUsername('taken', viewer: any(named: 'viewer')))
          .thenThrow(const UsernameException(UsernameFailure.taken));
      when(() => failing.claimUsername('broken', viewer: any(named: 'viewer')))
          .thenThrow(Exception('offline'));
      final bloc = build(failing)
        ..add(EditUsernameTextChanged('taken', viewer));
      await bloc.stream.firstWhere((s) => s.canSave);
      bloc.add(EditUsernameSavePressed(viewer));
      await bloc.stream.firstWhere((s) => s.status == UsernameStatus.taken);
      bloc.add(EditUsernameTextChanged('broken', viewer));
      await bloc.stream.firstWhere((s) => s.canSave);
      bloc.add(EditUsernameSavePressed(viewer));
      await bloc.stream.firstWhere((s) => s.failureId == 1);
      await bloc.close();
    });

    blocTest<EditUsernameBloc, EditUsernameState>(
      'says when availability cannot be checked',
      setUp: () => when(
        () => failing.isUsernameAvailable(any(), viewer: any(named: 'viewer')),
      ).thenThrow(Exception('offline')),
      build: () => build(failing),
      act: (bloc) => bloc
        ..add(EditUsernameTextChanged('new_one', viewer))
        ..add(EditUsernameSavePressed(viewer)),
      wait: const Duration(milliseconds: 10),
      skip: 1,
      expect: () => [
        const EditUsernameState(text: 'new_one', status: UsernameStatus.failed),
      ],
    );
  });

  group(PeopleSearchBloc, () {
    blocTest<PeopleSearchBloc, PeopleSearchState>(
      'finds people after a pause, less the reader',
      build: () => PeopleSearchBloc(social: social, debounce: Duration.zero),
      act: (bloc) async {
        bloc.add(PeopleSearchQueryChanged('al', viewer));
        await pumpEventQueue();
        bloc.add(PeopleSearchQueryChanged(' ', viewer));
      },
      expect: () => [
        const PeopleSearchState(query: 'al', isLoading: true),
        const PeopleSearchState(query: 'al'),
        const PeopleSearchState(query: ' '),
      ],
    );

    test('lists followed people first, matching the query', () {
      const maya = UserModel(userId: 'm', firstName: 'Maya');
      const mal = UserModel(userId: 'x', username: 'mal');
      const state = PeopleSearchState(query: 'ma', remoteUsers: [maya, mal]);
      expect(state.isSearching, isTrue);
      expect(state.results(const [maya, UserModel(userId: 'z')]), [maya, mal]);
    });

    blocTest<PeopleSearchBloc, PeopleSearchState>(
      'says when the search failed',
      setUp: () =>
          when(() => failing.searchUsers(any(), viewer: any(named: 'viewer')))
              .thenThrow(Exception('offline')),
      build: () => PeopleSearchBloc(social: failing, debounce: Duration.zero),
      act: (bloc) => bloc.add(PeopleSearchQueryChanged('bob', viewer)),
      wait: const Duration(milliseconds: 10),
      skip: 1,
      expect: () => [const PeopleSearchState(query: 'bob', failed: true)],
    );
  });

  group(SocialCubit, () {
    test('suggests people and tracks taps', () async {
      final cubit = SocialCubit(social: social, analytics: analytics)
        ..appeared()
        ..pressed('FindPeople_Press');
      await cubit.loadSuggestions(viewer);
      expect(cubit.state.map((u) => u.userId), ['user6']);
      cubit.disappeared();
      expect(events, [
        'SocialView_Appear',
        'SocialView_FindPeople_Press',
        'SocialView_Disappear',
      ]);
    });

    test('suggests nobody when the read fails', () async {
      when(() => failing.suggestedUsers(viewer: any(named: 'viewer')))
          .thenThrow(Exception('offline'));
      final cubit = SocialCubit(social: failing, analytics: analytics);
      await cubit.loadSuggestions(viewer);
      expect(cubit.state, isEmpty);
      expect(events, ['SocialView_LoadSuggestedUsers_Fail']);
    });
  });

  group(SocialProfileCubit, () {
    test('reads followers and workouts, and blocks', () async {
      final cubit = SocialProfileCubit(
        social: social,
        analytics: analytics,
        userId: 'user1',
      );
      await cubit.appeared(viewer);
      expect(cubit.state.user?.userId, 'user1');
      expect(cubit.state.followers.map((u) => u.userId), ['user3', 'user5']);
      expect(cubit.state.sessions, hasLength(2));
      cubit.tabChanged(SocialProfileTab.activities);
      expect(cubit.state.tab, SocialProfileTab.activities);
      await cubit.followingPressed(viewer);
      expect(cubit.state.following, isNotNull);
      expect(cubit.state.followingId, 1);
      await cubit.blockConfirmed(viewer);
      expect((await users.watchUser(sampleUserId).first)!.blockedUserIds, [
        'user1',
      ]);
      await cubit.unblockPressed((await users.watchUser(sampleUserId).first)!);
      cubit
        ..followPressed(following: true, requested: false)
        ..followPressed(following: false, requested: true)
        ..followPressed(following: false, requested: false)
        ..settingsPressed()
        ..editProfilePressed()
        ..weeklyGoalPressed()
        ..disappeared();
      expect(events, [
        'SocialProfileView_Appear',
        'SocialProfileView_Block_Confirmed',
        'SocialProfileView_Block_Start',
        'SocialProfileView_Block_Success',
        'SocialProfileView_Unblock_Pressed',
        'SocialProfileView_Unblock_Start',
        'SocialProfileView_Unblock_Success',
        'SocialProfileView_Unfollow_Pressed',
        'SocialProfileView_CancelRequest_Pressed',
        'SocialProfileView_Follow_Pressed',
        'SocialProfileView_Settings_Pressed',
        'SocialProfileView_EditProfile_Pressed',
        'SocialProfileView_WeeklyGoal_Pressed',
        'SocialProfileView_Disappear',
      ]);
    });

    test('keeps a private profile’s workouts to its followers', () async {
      final cubit = SocialProfileCubit(
        social: social,
        analytics: analytics,
        userId: 'user2',
      );
      await cubit.appeared(viewer);
      expect(cubit.state.user?.isPrivate, isTrue);
      expect(cubit.state.isLoadingSessions, isFalse);
      expect(cubit.state.sessions, isEmpty);
    });

    test('says what failed', () async {
      when(() => failing.followersOf(any(), viewer: any(named: 'viewer')))
          .thenThrow(Exception('offline'));
      when(() => failing.sessionsByAuthor(any(), limit: any(named: 'limit')))
          .thenThrow(Exception('offline'));
      when(() => failing.users(any(), viewer: any(named: 'viewer')))
          .thenThrow(Exception('offline'));
      when(() => failing.block(any(), viewer: any(named: 'viewer')))
          .thenThrow(Exception('denied'));
      when(() => failing.unblock(any(), viewer: any(named: 'viewer')))
          .thenThrow(Exception('denied'));
      final cubit = SocialProfileCubit(
        social: failing,
        analytics: analytics,
        userId: 'user1',
        user: const UserModel(userId: 'user1', followingIds: ['user3']),
      );
      await cubit.appeared(viewer);
      expect(cubit.state.loadSessionsFailed, isTrue);
      await cubit.followingPressed(viewer);
      expect(cubit.state.notice, SocialProfileNotice.followingFailed);
      await cubit.blockConfirmed(viewer);
      expect(cubit.state.notice, SocialProfileNotice.blockFailed);
      await cubit.unblockPressed(viewer);
      expect(cubit.state.notice, SocialProfileNotice.unblockFailed);
      expect(cubit.state.noticeId, 3);

      // A profile that cannot be read stays unread.
      final unread = SocialProfileCubit(
        social: failing,
        analytics: analytics,
        userId: 'gone',
      );
      await unread.appeared(viewer);
      expect(unread.state.user, isNull);
      await unread.followingPressed(viewer);
      expect(unread.state.following, isNull);
    });
  });
}
