import 'package:compound/sharing/cubit/share_to_follower_cubit.dart';
import 'package:compound/sharing/cubit/shared_item_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:program_repository/program_repository.dart';
import 'package:social_repository/social_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../helpers/helpers.dart';

class _MockSocial extends Mock implements SocialRepository;

/// Ported from `MesocycleSharingTests`.
void main() {
  final now = DateTime(2026, 10, 15, 12);
  late _MockSocial social;
  late AnalyticsRecorder analytics;

  setUpAll(() {
    registerFallbackValue(const UserModel(userId: 'x'));
    registerFallbackValue(ShareStatus.pending);
    registerFallbackValue(
      TemplateSharePayload(PrebuiltCatalogue.instance.workoutTemplates.first),
    );
  });

  setUp(() {
    social = _MockSocial();
    analytics = AnalyticsRecorder();
  });

  final catalogue = PrebuiltCatalogue.instance;
  final system = catalogue.exercises.first;
  final custom = ExerciseModel.fromFirestore({
    ...catalogue.exercises[1].toFirestore(),
    ExerciseModelKeys.id: 'alice-custom',
    ExerciseModelKeys.authorId: 'alice',
    ExerciseModelKeys.isSystemExercise: false,
  });
  WorkoutTemplateModel template({String id = 'alice-template'}) {
    final slot = catalogue.workoutTemplates.first.exercises.first;
    return WorkoutTemplateModel(
      workoutId: id,
      authorId: 'alice',
      name: 'Push Day',
      gymProfileId: 'alice-gym',
      dateCreated: now,
      dateModified: now,
      exercises: [
        for (final (index, exercise) in [system, custom, custom].indexed)
          WorkoutTemplateExercise.fromFirestore({
            ...slot.toFirestore(),
            WorkoutTemplateExerciseKeys.id: 'slot-$index',
            WorkoutTemplateExerciseKeys.exercise: exercise.toFirestore(),
          }),
      ],
    );
  }

  group(ShareToFollowerCubit, () {
    const me = UserModel(userId: 'me', blockedUserIds: ['blocked']);

    ShareToFollowerCubit build(List<UserModel> following) =>
        ShareToFollowerCubit(
          social: social,
          analytics: analytics,
          viewer: me,
          payload: TemplateSharePayload(template()),
          following: following,
        );

    test('lists only unblocked mutuals', () {
      final cubit = build(const [
        UserModel(userId: 'mutual', followingIds: ['me']),
        UserModel(userId: 'oneway', followingIds: ['someone']),
        UserModel(userId: 'blocked', followingIds: ['me']),
      ]);
      expect(
        [for (final user in cubit.state.recipients) user.userId],
        ['mutual'],
      );
    });

    test('sends to each selected recipient in list order', () async {
      when(
        () => social.sendShare(
          any(),
          recipientIds: any(named: 'recipientIds'),
          viewer: me,
        ),
      ).thenAnswer((_) async {});
      final cubit = build([
        for (final id in ['amy', 'bob', 'cal'])
          UserModel(userId: id, followingIds: const ['me']),
      ])..appeared();
      expect(cubit.state.canSend, isFalse);
      cubit
        ..recipientPressed('cal')
        ..recipientPressed('bob')
        ..recipientPressed('amy')
        ..recipientPressed('bob');
      await cubit.sendPressed();

      final payload =
          verify(
                () => social.sendShare(
                  captureAny(),
                  recipientIds: ['amy', 'cal'],
                  viewer: me,
                ),
              ).captured.single
              as TemplateSharePayload;
      expect(payload.template.name, 'Push Day');
      expect(cubit.state.status, ShareSendStatus.sent);
      expect(analytics.parameters('ShareToFollowerView_Send_Start'), {
        'kind': 'template',
        'recipient_count': 2,
      });
      expect(analytics.names, [
        'ShareToFollowerView_Appear',
        'ShareToFollowerView_Send_Start',
        'ShareToFollowerView_Send_Success',
      ]);
    });

    test('a failed send says so and can be retried', () async {
      when(
        () => social.sendShare(
          any(),
          recipientIds: any(named: 'recipientIds'),
          viewer: me,
        ),
      ).thenThrow(StateError('x'));
      final cubit = build(const [
        UserModel(userId: 'amy', followingIds: ['me']),
      ])..recipientPressed('amy');
      await cubit.sendPressed();
      expect(cubit.state.status, ShareSendStatus.failed);
      expect(cubit.state.failureId, 1);
      expect(cubit.state.canSend, isTrue);
      expect(analytics.names.last, 'ShareToFollowerView_Send_Fail');
      cubit.disappeared();
      expect(analytics.names.last, 'ShareToFollowerView_Disappear');
    });
  });

  group(SharedItemCubit, () {
    late InMemoryTrainingLibraryRepository library;
    late InMemoryProgramRepository programs;
    late List<String> answers;
    var count = 0;

    setUp(() {
      library = InMemoryTrainingLibraryRepository();
      programs = InMemoryProgramRepository();
      answers = [];
      count = 0;
      when(() => social.answerShare(any(), any())).thenAnswer((call) async {
        answers.add(
          '${(call.positionalArguments[1] as ShareStatus).value}:'
          '${call.positionalArguments[0]}',
        );
      });
    });

    SharedItemCubit build(
      SharePayload payload, {
      TrainingLibraryRepository? with_,
    }) => SharedItemCubit(
      social: social,
      library: with_ ?? library,
      programs: programs,
      analytics: analytics,
      uid: 'me',
      shareId: 'share-1',
      share: ShareModel(
        id: 'share-1',
        fromUserId: 'alice',
        toUserId: 'me',
        payload: payload,
        dateCreated: now,
      ),
      now: () => now,
      newId: () => 'new-${++count}',
    );

    test(
      'accepting a template copies it under the recipient with new ids',
      () async {
        final cubit = build(TemplateSharePayload(template()));
        await cubit.load();
        await cubit.addToLibraryPressed();

        final saved = await library.watchUserWorkoutTemplates('me').first;
        expect(saved, hasLength(1));
        final copy = saved.single;
        expect(copy.workoutId, isNot('alice-template'));
        expect(copy.authorId, 'me');
        expect(copy.gymProfileId, isNull);
        final exercises = await library.watchUserExercises('me').first;
        expect(exercises, hasLength(1));
        final added = exercises.single;
        expect(added.id, isNot('alice-custom'));
        expect(added.authorId, 'me');
        expect(
          [for (final item in copy.exercises) item.exercise.id],
          [system.id, added.id, added.id],
        );
        expect(answers, ['accepted:share-1']);
        expect(cubit.state.status, ShareStatus.accepted);
        expect(cubit.state.answered, isTrue);
        expect(analytics.names, [
          'SharedItemView_Appear',
          'SharedItemView_Accept_Start',
          'SharedItemView_Accept_Success',
        ]);
        expect(analytics.parameters('SharedItemView_Appear'), {
          'kind': 'template',
        });
      },
    );

    test('accepting a mesocycle copies every day', () async {
      final mesocycle = Mesocycle(
        id: 'alice-program',
        authorId: 'alice',
        name: 'Block',
        icon: 'flag',
        colour: '#FF0000',
        workoutTemplates: [
          template(id: 'day-1'),
          template(id: 'day-2'),
        ],
        dateCreated: now,
        dateModified: now,
      );
      final cubit = build(MesocycleSharePayload(mesocycle));
      await cubit.addToLibraryPressed();

      final saved = await programs.watchMesocycles('me').first;
      final copy = saved.single;
      expect(copy.id, isNot('alice-program'));
      expect(copy.authorId, 'me');
      expect(copy.workoutTemplates, hasLength(2));
      expect(
        copy.workoutTemplates.any(
          (day) =>
              ['day-1', 'day-2'].contains(day.workoutId) ||
              day.authorId != 'me',
        ),
        isFalse,
      );
      expect(await library.watchUserExercises('me').first, hasLength(1));
      expect(answers, ['accepted:share-1']);
    });

    test('a failed copy leaves the share pending', () async {
      final failing = _FailingLibrary();
      final cubit = build(TemplateSharePayload(template()), with_: failing);
      await cubit.addToLibraryPressed();
      expect(cubit.state.notice, SharedItemNotice.addFailed);
      expect(cubit.state.status, ShareStatus.pending);
      expect(cubit.state.isWorking, isFalse);
      expect(answers, isEmpty);
      expect(analytics.names.last, 'SharedItemView_Answer_Fail');
    });

    test('declining marks the share and saves nothing', () async {
      final cubit = build(TemplateSharePayload(template()));
      await cubit.declinePressed();
      expect(answers, ['dismissed:share-1']);
      expect(cubit.state.status, ShareStatus.dismissed);
      expect(await library.watchUserWorkoutTemplates('me').first, isEmpty);
      expect(analytics.names, [
        'SharedItemView_Dismiss_Start',
        'SharedItemView_Dismiss_Success',
      ]);

      when(() => social.answerShare(any(), any())).thenThrow(StateError('x'));
      final failing = build(TemplateSharePayload(template()));
      await failing.declinePressed();
      expect(failing.state.notice, SharedItemNotice.declineFailed);
      failing.disappeared();
      expect(analytics.names.last, 'SharedItemView_Disappear');
    });

    test(
      'opened by id, it reads the share; a missing one is not found',
      () async {
        final share = ShareModel(
          id: 'share-1',
          fromUserId: 'alice',
          toUserId: 'me',
          payload: TemplateSharePayload(template()),
          dateCreated: now,
          status: ShareStatus.accepted,
        );
        when(() => social.share('share-1')).thenAnswer((_) async => share);
        SharedItemCubit byId() => SharedItemCubit(
          social: social,
          library: library,
          programs: programs,
          analytics: analytics,
          uid: 'me',
          shareId: 'share-1',
        );
        final cubit = byId();
        await cubit.load();
        expect(cubit.state.share, share);
        expect(cubit.state.isAnswered, isTrue);
        expect(cubit.state.templates.single.name, 'Push Day');

        when(() => social.share('share-1')).thenAnswer((_) async => null);
        final missing = byId();
        await missing.load();
        expect(missing.state.notFound, isTrue);
        expect(missing.state.templates, isEmpty);

        when(() => social.share('share-1')).thenThrow(StateError('x'));
        final failing = byId();
        await failing.load();
        expect(failing.state.notFound, isTrue);
        await failing.addToLibraryPressed();
        await failing.declinePressed();
        expect(answers, isEmpty);
      },
    );
  });
}

class _FailingLibrary extends InMemoryTrainingLibraryRepository {
  @override
  Future<void> saveUserExercise(ExerciseModel exercise) =>
      Future.error(StateError('offline'));
}
