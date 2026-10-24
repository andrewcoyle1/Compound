import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/coach/coach.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

/// Swift `CoachTests`, case for case: the gate (premium, then consent), the
/// streamed answer, what a refusal does, the saved chats, and the ways in.
void main() {
  const uid = 'user-1';
  final asked = DateTime.utc(2026, 10, 14, 9);
  late FakeFirebaseFirestore firestore;
  late InMemoryUserRepository users;
  late AnalyticsRecorder analytics;
  late List<(String, String?, CoachContext?)> sent;
  late List<CoachStreamEvent> events;
  late CoachFailure? refusal;
  late int ids;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    users = InMemoryUserRepository();
    analytics = AnalyticsRecorder();
    sent = [];
    events = const [
      CoachText('Hello '),
      CoachText('there'),
      CoachFinished(
        chatId: 'c1',
        messageId: 'a1',
        text: 'Hello there',
        remainingToday: 49,
      ),
    ];
    refusal = null;
    ids = 0;
  });

  CoachRepository coach() => CoachRepository(
    firestore: firestore,
    users: users,
    coachChat: (message, {chatId, context}) {
      sent.add((message, chatId, context));
      final failure = refusal;
      return failure == null
          ? Stream.fromIterable(events)
          : Stream.error(CoachException(failure));
    },
  );

  Future<void> consent() => users.mergePrivateSettings(
    uid,
    const PrivateUserSettings(coachConsent: true),
  );

  Future<CoachCubit> screen({
    CoachRequest request = const CoachRequest(),
    bool premium = true,
    CoachRepository? repository,
  }) async {
    final purchases = FakePurchasesRepository(premium: premium);
    await purchases.logIn(uid);
    return CoachCubit(
      uid: uid,
      request: request,
      coach: repository ?? coach(),
      purchases: purchases,
      analytics: analytics,
      now: () => asked,
      newId: () => 'q${++ids}',
    );
  }

  final sampleChat = CoachChat(
    id: 'chat-1',
    title: 'Why has my weight stalled?',
    createdAt: asked,
    updatedAt: asked,
    contextKind: 'weight_trend',
    messages: [
      CoachMessage(
        id: 'm1',
        role: CoachMessageRole.user,
        text: 'Why has my weight stalled?',
        createdAt: asked,
      ),
      CoachMessage(
        id: 'm2',
        role: CoachMessageRole.assistant,
        text: "You've been at maintenance.",
        createdAt: asked,
      ),
    ],
  );

  group('the gate', () {
    test('is premium, then consent, then chat', () async {
      final notPremium = await screen(premium: false);
      await notPremium.appeared();
      expect(notPremium.state.gate, CoachGate.premium);
      notPremium.seePlansPressed();
      expect(analytics.names, contains('CoachView_SeePlans_Press'));

      final noConsent = await screen();
      await noConsent.appeared();
      expect(noConsent.state.gate, CoachGate.consent);

      await consent();
      final ready = await screen();
      await ready.appeared();
      expect(ready.state.gate, CoachGate.chat);
      expect(analytics.parameters('CoachView_Appear'), {'context': 'today'});
    });

    test('agreeing opens the chat; declining is logged', () async {
      final cubit = await screen();
      await cubit.appeared();

      await cubit.consentAccepted();

      expect(cubit.state.gate, CoachGate.chat);
      expect(cubit.state.isGivingConsent, isFalse);
      expect(
        (await users.watchPrivateSettings(uid).first)?.coachConsent,
        isTrue,
      );
      expect(
        analytics.names,
        containsAllInOrder([
          'CoachView_Consent_Start',
          'CoachView_Consent_Success',
        ]),
      );

      cubit.consentDeclined();
      expect(analytics.names.last, 'CoachView_Consent_Declined');
    });
  });

  group('sending', () {
    setUp(consent);

    test('a message streams its answer and keeps the chat', () async {
      final cubit = await screen(
        request: const CoachRequest(
          context: CoachContext(
            kind: CoachContextKind.exercise,
            id: 'bench',
            title: 'Bench Press',
          ),
        ),
      );
      await cubit.appeared();
      final streamed = <String?>[];
      final subscription = cubit.stream.listen(
        (state) => streamed.add(state.streamingText),
      );
      cubit.draftChanged('  Is my bench progressing?  ');

      await cubit.sendPressed();

      expect(cubit.state.isSending, isFalse);
      expect(cubit.state.messages.map((m) => m.text), [
        'Is my bench progressing?',
        'Hello there',
      ]);
      expect(cubit.state.messages.map((m) => m.role), [
        CoachMessageRole.user,
        CoachMessageRole.assistant,
      ]);
      expect(cubit.state.streamingText, isNull);
      expect(streamed, containsAllInOrder(['', 'Hello ', 'Hello there']));
      expect(sent.single.$3?.id, 'bench');
      expect(sent.single.$2, isNull);
      expect(analytics.parameters('CoachView_Send_Start'), {
        'context': 'exercise',
        'is_new_chat': true,
      });

      cubit.draftChanged('And squat?');
      await cubit.sendPressed();
      expect(sent.last.$2, 'c1');
      await subscription.cancel();
    });

    test('blocks accumulate as they stream and stay with the answer', () async {
      const chart = CoachBlock(
        surfaceId: 'a1-0',
        kind: 'trend_chart',
        asOf: '2026-10-14',
        fallback: 'Weight trend.',
        messages: [],
      );
      const followUps = CoachBlock(
        surfaceId: 'a1-1',
        kind: 'follow_ups',
        asOf: '2026-10-14',
        fallback: 'Suggested questions.',
        messages: [],
      );
      events = const [
        CoachText('Hello'),
        CoachBlockShown(chart),
        CoachBlockShown(followUps),
        CoachFinished(
          chatId: 'c1',
          messageId: 'a1',
          text: 'Hello',
          remainingToday: 49,
          blocks: [chart, followUps],
        ),
      ];
      final cubit = await screen();
      await cubit.appeared();
      final streamed = <List<String>>[];
      final subscription = cubit.stream.listen(
        (state) => streamed.add([
          for (final block in state.streamingBlocks) block.surfaceId,
        ]),
      );
      cubit.draftChanged('How am I doing?');

      await cubit.sendPressed();

      expect(
        streamed,
        containsAllInOrder([
          ['a1-0'],
          ['a1-0', 'a1-1'],
          <String>[],
        ]),
      );
      expect(cubit.state.streamingBlocks, isEmpty);
      expect(cubit.state.messages.last.blocks, [chart, followUps]);
      expect(cubit.state.messages.first.blocks, isNull);
      expect(cubit.state.savedMessageCount, 0);
      await subscription.cancel();
    });

    test('an answer without blocks stores none', () async {
      final cubit = await screen();
      await cubit.appeared();
      cubit.draftChanged('Hi');

      await cubit.sendPressed();

      expect(cubit.state.messages.last.blocks, isNull);
    });

    test('a failed answer drops the blocks it streamed', () async {
      final repository = CoachRepository(
        firestore: firestore,
        users: users,
        coachChat: (message, {chatId, context}) async* {
          yield const CoachBlockShown(
            CoachBlock(
              surfaceId: 'a1-0',
              kind: 'actions',
              asOf: '2026-10-14',
              fallback: 'You can: Log weight.',
              messages: [],
            ),
          );
          throw const CoachException(CoachFailure.unavailable);
        },
      );
      final cubit = await screen(repository: repository);
      await cubit.appeared();
      cubit.draftChanged('Hi');

      await cubit.sendPressed();

      expect(cubit.state.streamingBlocks, isEmpty);
      expect(cubit.state.questions, {
        'q1': const CoachQuestionStatus.failed(CoachFailure.unavailable),
      });
    });

    test("a saved chat replays its answers' blocks", () async {
      const block = CoachBlock(
        surfaceId: 'm2-0',
        kind: 'stat_row',
        asOf: '2026-10-13',
        fallback: 'Trend weight: 72.3 kg.',
        messages: [],
      );
      final m2 = sampleChat.messages.last;
      final cubit = await screen(
        request: CoachRequest.forChat(
          CoachChat(
            id: sampleChat.id,
            title: sampleChat.title,
            createdAt: asked,
            updatedAt: asked,
            messages: [
              sampleChat.messages.first,
              CoachMessage(
                id: m2.id,
                role: m2.role,
                text: m2.text,
                createdAt: asked,
                blocks: const [block],
              ),
            ],
          ),
          CoachContext.today,
        ),
      );

      expect(cubit.state.messages.last.blocks, [block]);
      expect(cubit.state.savedMessageCount, 2);
    });

    test('an empty message is not sent', () async {
      final cubit = await screen()
        ..draftChanged('   ');
      expect(cubit.state.canSend, isFalse);

      await cubit.sendPressed();

      expect(sent, isEmpty);
    });

    test('a failed question stays in the conversation, marked', () async {
      refusal = CoachFailure.dailyLimitReached;
      final cubit = await screen()
        ..draftChanged('How was my week?');

      await cubit.sendPressed();

      expect(cubit.state.isSending, isFalse);
      expect(cubit.state.messages.map((m) => m.text), ['How was my week?']);
      expect(cubit.state.draft, isEmpty);
      expect(cubit.state.draftRevision, 1);
      expect(cubit.state.questions, {
        'q1': const CoachQuestionStatus.failed(CoachFailure.dailyLimitReached),
      });
      expect(cubit.state.remainingToday, 0);
      expect(cubit.state.sendFailures, 1);
      expect(analytics.parameters('CoachView_Send_Fail'), {
        'reason': 'dailyLimitReached',
      });
    });

    test("an error that is not the coach's reads as unavailable", () async {
      final cubit =
          await screen(
              repository: CoachRepository(
                firestore: firestore,
                users: users,
                coachChat: (_, {chatId, context}) =>
                    Stream.error(StateError('x')),
              ),
            )
            ..draftChanged('Hi');

      await cubit.sendPressed();

      expect(
        cubit.state.questions['q1'],
        const CoachQuestionStatus.failed(CoachFailure.unavailable),
      );
    });

    test('a refusal for consent or premium returns to the gate', () async {
      refusal = CoachFailure.consentRequired;
      final consentRefused = await screen()
        ..draftChanged('hi');
      await consentRefused.sendPressed();
      expect(consentRefused.state.gate, CoachGate.consent);
      // As before: the question goes back in the field.
      expect(consentRefused.state.questions, isEmpty);
      expect(consentRefused.state.messages, isEmpty);
      expect(consentRefused.state.draft, 'hi');

      refusal = CoachFailure.premiumRequired;
      final premiumRefused = await screen()
        ..draftChanged('hi');
      await premiumRefused.sendPressed();
      expect(premiumRefused.state.gate, CoachGate.premium);
    });

    test('suggested questions show until the first message and send when '
        'tapped', () async {
      final cubit = await screen(
        request: const CoachRequest(
          context: CoachContext(kind: CoachContextKind.weightTrend),
        ),
      );
      expect(cubit.state.showsSuggestions, isTrue);

      await cubit.suggestionPressed('Why has my weight changed this month?');

      expect(sent.single.$1, 'Why has my weight changed this month?');
      expect(cubit.state.showsSuggestions, isFalse);
    });

    test('an opened chat shows its messages and continues it', () async {
      final cubit = await screen(
        request: CoachRequest.forChat(sampleChat, CoachContext.today),
      );
      expect(cubit.state.messages, hasLength(2));
      expect(cubit.state.savedMessageCount, 2);
      expect(cubit.state.chatTitle, 'Why has my weight stalled?');

      cubit.draftChanged('And now?');
      await cubit.sendPressed();
      expect(sent.single.$2, 'chat-1');
      // The saved replies replay as saved; this session's are live.
      expect(cubit.state.messages, hasLength(4));
      expect(cubit.state.savedMessageCount, 2);

      cubit.newChatPressed();
      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.savedMessageCount, 0);
      expect(cubit.state.chatId, isNull);
      expect(analytics.names.last, 'CoachView_NewChat_Press');
    });

    test(
      'a new chat takes its saved title once the function saves it',
      () async {
        final cubit = await screen();
        await cubit.appeared();
        cubit.draftChanged('How am I doing?');
        await cubit.sendPressed();

        await firestore
            .doc('users/$uid/coach_chats/c1')
            .set(
              CoachChat(
                id: 'c1',
                title: 'How am I doing?',
                createdAt: asked,
                updatedAt: asked,
                messages: const [],
              ).toFirestore(),
            );
        await pumpEventQueue();

        expect(cubit.state.chatTitle, 'How am I doing?');
        await cubit.close();
      },
    );

    test('the few messages left are shown', () async {
      final repository = coach();
      events = const [
        CoachFinished(
          chatId: 'c',
          messageId: 'a',
          text: 'a',
          remainingToday: 40,
        ),
      ];
      await repository.send(uid, 'hi').drain<void>();
      expect(
        (await screen(repository: repository)).state.remainingShown,
        isNull,
      );

      events = const [
        CoachFinished(
          chatId: 'c',
          messageId: 'a',
          text: 'a',
          remainingToday: 3,
        ),
      ];
      await repository.send(uid, 'hi').drain<void>();
      expect((await screen(repository: repository)).state.remainingShown, 3);
    });

    test('analytics never carry the message', () async {
      final cubit = await screen()
        ..draftChanged('My knee hurts');

      await cubit.sendPressed();

      final values = [
        for (final event in analytics.events)
          ...?event.parameters?.values.map((value) => '$value'),
      ];
      expect(values.where((value) => value.contains('knee')), isEmpty);
    });

    test('a screen closed while answering stops quietly', () async {
      final answer = StreamController<CoachStreamEvent>();
      final cubit =
          await screen(
              repository: CoachRepository(
                firestore: firestore,
                users: users,
                coachChat: (_, {chatId, context}) => answer.stream,
              ),
            )
            ..draftChanged('Hi');

      final sending = cubit.sendPressed();
      await cubit.close();
      answer.add(const CoachText('late'));
      await answer.close();
      await sending;

      expect(cubit.isClosed, isTrue);
    });
  });

  group('stop, retry and feedback', () {
    late StreamController<CoachStreamEvent> answer;

    setUp(() => answer = StreamController<CoachStreamEvent>());
    // Not awaited: a stream nobody listened to never reports done.
    tearDown(() => unawaited(answer.close()));

    CoachCubit build({CoachRepository? repository}) => CoachCubit(
      uid: uid,
      request: const CoachRequest(),
      coach:
          repository ??
          CoachRepository(
            firestore: firestore,
            users: users,
            coachChat: (_, {chatId, context}) => answer.stream,
          ),
      purchases: FakePurchasesRepository(),
      analytics: analytics,
      now: () => asked,
      newId: () => 'q${++ids}',
    );

    blocTest<CoachCubit, CoachState>(
      'Stop drops what streamed and leaves the question stopped',
      build: build,
      act: (cubit) async {
        cubit.draftChanged('How is my week?');
        final sending = cubit.sendPressed();
        answer.add(const CoachText('Your week'));
        await pumpEventQueue();
        expect(cubit.state.isSending, isTrue);
        cubit.stopPressed();
        await sending;
        // Too late: the answer is no longer read.
        answer.add(const CoachText(' was good'));
        await pumpEventQueue();
      },
      verify: (cubit) {
        expect(cubit.state.isSending, isFalse);
        expect(cubit.state.streamingText, isNull);
        expect(cubit.state.messages.map((m) => m.text), ['How is my week?']);
        expect(cubit.state.questions, {
          'q1': const CoachQuestionStatus.stopped(),
        });
        expect(analytics.parameters('CoachView_Stop_Press'), {
          'context': 'today',
        });
        // Nothing to stop once it has.
        cubit.stopPressed();
        expect(
          analytics.names.where((name) => name == 'CoachView_Stop_Press'),
          hasLength(1),
        );
      },
    );

    blocTest<CoachCubit, CoachState>(
      'Retry asks a failed question again, as the newest message',
      setUp: () => refusal = CoachFailure.unavailable,
      build: () => build(repository: coach()),
      act: (cubit) async {
        cubit.draftChanged('First?');
        await cubit.sendPressed();
        refusal = null;
        cubit.draftChanged('Second?');
        await cubit.sendPressed();

        await cubit.retryPressed('q1');
        // Not a question, or not one left to retry.
        await cubit.retryPressed('q1');
      },
      verify: (cubit) {
        expect(cubit.state.messages.map((m) => m.text), [
          'Second?',
          'Hello there',
          'First?',
          'Hello there',
        ]);
        expect(cubit.state.questions, isEmpty);
        expect(sent.map((call) => call.$1), ['First?', 'Second?', 'First?']);
        expect(analytics.parameters('CoachView_Retry_Press'), {
          'context': 'today',
        });
      },
    );

    blocTest<CoachCubit, CoachState>(
      'an answer that ends without finishing fails the question',
      build: build,
      act: (cubit) async {
        cubit.draftChanged('Hi');
        final sending = cubit.sendPressed();
        answer.add(const CoachText('Hel'));
        await answer.close();
        await sending;
      },
      verify: (cubit) {
        expect(
          cubit.state.questions['q1'],
          const CoachQuestionStatus.failed(CoachFailure.unavailable),
        );
        expect(cubit.state.streamingText, isNull);
        expect(cubit.state.sendFailures, 1);
      },
    );

    blocTest<CoachCubit, CoachState>(
      'Retry waits while another question is answered',
      build: build,
      seed: () => CoachState(
        gate: CoachGate.chat,
        messages: [
          CoachMessage(
            id: 'old',
            role: CoachMessageRole.user,
            text: 'Old?',
            createdAt: asked,
          ),
        ],
        questions: const {
          'old': CoachQuestionStatus.stopped(),
          'now': CoachQuestionStatus.answering(),
        },
      ),
      act: (cubit) => cubit.retryPressed('old'),
      expect: () => <CoachState>[],
    );

    blocTest<CoachCubit, CoachState>(
      'copy and feedback carry the rating and context, never the text',
      build: build,
      act: (cubit) => cubit
        ..copyPressed(CoachMessageRole.assistant)
        ..feedbackGiven(helpful: true)
        ..feedbackGiven(helpful: false),
      verify: (_) {
        expect(analytics.parameters('CoachView_Copy_Press'), {
          'context': 'today',
          'role': 'assistant',
        });
        expect(
          [
            for (final event in analytics.events)
              if (event.eventName == 'CoachView_Feedback') event.parameters,
          ],
          [
            {'context': 'today', 'rating': 'up'},
            {'context': 'today', 'rating': 'down'},
          ],
        );
      },
    );
  });

  group('CoachRequest.forChat', () {
    test("opens a chat in its own context, or the list's", () {
      final request = CoachRequest.forChat(sampleChat, CoachContext.today);
      expect(request.context.kind, CoachContextKind.weightTrend);
      expect(request.chat?.id, 'chat-1');
      expect(request.showsCloseButton, isFalse);

      final unknown = CoachRequest.forChat(
        CoachChat(
          id: 'x',
          title: 'x',
          createdAt: asked,
          updatedAt: asked,
          messages: const [],
        ),
        const CoachContext(kind: CoachContextKind.session),
      );
      expect(unknown.context.kind, CoachContextKind.session);
    });
  });

  group('CoachChatsCubit', () {
    CoachChatsCubit list({CoachRepository? repository}) => CoachChatsCubit(
      uid: uid,
      coach: repository ?? coach(),
      analytics: analytics,
    );

    test('reads the chats newest first and the permission', () async {
      final older = CoachChat(
        id: 'old',
        title: 'Old',
        createdAt: asked,
        updatedAt: asked,
        messages: const [],
      );
      final newer = CoachChat(
        id: 'new',
        title: 'New',
        createdAt: asked,
        updatedAt: asked.add(const Duration(hours: 1)),
        messages: const [],
      );
      for (final chat in [older, newer]) {
        await firestore
            .doc('users/$uid/coach_chats/${chat.id}')
            .set(chat.toFirestore());
      }
      await consent();
      final cubit = list()..started();
      await pumpEventQueue();

      expect(cubit.state.chats?.map((chat) => chat.id), ['new', 'old']);
      expect(cubit.state.hasConsented, isTrue);
      await cubit.close();
    });

    test('withdraws after asking, deleting every chat', () async {
      await consent();
      await firestore
          .doc('users/$uid/coach_chats/chat-1')
          .set(sampleChat.toFirestore());
      final cubit = list()..started();

      await cubit.withdrawConfirmed();

      expect(cubit.state.notice, CoachChatsNotice.withdrawn);
      expect(cubit.state.isWithdrawing, isFalse);
      final settings = await users.watchPrivateSettings(uid).first;
      // Written false, not removed: saves merge.
      expect(settings?.coachConsent, isFalse);
      expect(
        (await firestore.collection('users/$uid/coach_chats').get()).docs,
        isEmpty,
      );
      expect(
        analytics.names,
        containsAllInOrder([
          'CoachChatsView_Withdraw_Start',
          'CoachChatsView_Withdraw_Success',
        ]),
      );
      await cubit.close();
    });

    test('deletes a chat', () async {
      await firestore
          .doc('users/$uid/coach_chats/chat-1')
          .set(sampleChat.toFirestore());
      final cubit = list()
        ..appeared()
        ..chatPressed()
        ..newChatPressed();

      await cubit.deleteChat(sampleChat);

      expect(
        (await firestore.doc('users/$uid/coach_chats/chat-1').get()).exists,
        isFalse,
      );
      cubit.disappeared();
      expect(analytics.names, [
        'CoachChatsView_Appear',
        'CoachChatsView_Chat_Press',
        'CoachChatsView_NewChat_Press',
        'CoachChatsView_DeleteChat_Start',
        'CoachChatsView_DeleteChat_Success',
        'CoachChatsView_Disappear',
      ]);
    });
  });
}
