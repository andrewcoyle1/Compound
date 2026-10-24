import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

import '../helpers/contract.dart';

Matcher _failure(CoachFailure failure) =>
    isA<CoachException>().having((error) => error.failure, 'failure', failure);

void main() {
  const uid = 'user-1';
  final now = DateTime.utc(2026, 10, 15, 9);
  late FakeFirebaseFirestore firestore;
  late InMemoryUserRepository users;
  late List<String> undecodable;
  late List<(String, String?, CoachContext?, bool)> sent;

  CoachRepository subject({CoachChatCall? coachChat}) => CoachRepository(
    firestore: firestore,
    users: users,
    coachChat:
        coachChat ??
        (message, {chatId, context, regenerate = false}) {
          sent.add((message, chatId, context, regenerate));
          return Stream.value(const CoachText('hi'));
        },
    now: () => now,
    onDecodeError: (path, _, _) => undecodable.add(path),
  );

  CollectionReference<Map<String, dynamic>> chats([String owner = uid]) =>
      firestore.collection('users/$owner/coach_chats');

  setUp(() {
    firestore = FakeFirebaseFirestore();
    users = InMemoryUserRepository();
    undecodable = [];
    sent = [];
  });

  group('watchChats', () {
    test('reads the function shape, newest first, skipping what does not '
        'decode', () async {
      await chats().doc('a').set(storedFixture('coach_chat', 'minimal'));
      await chats().doc('b').set(storedFixture('coach_chat', 'full'));
      await chats()
          .doc('c')
          .set(storedFixture('coach_chat', 'legacy-null-context-kind'));
      await chats().doc('bad').set({'id': 'bad'});

      final list = await subject().watchChats(uid).first;

      expect(
        [for (final chat in list) chat.id],
        ['chat_contract_legacy', 'chat_contract_minimal', 'chat_contract_full'],
      );
      final full = list.last;
      expect(full.contextKind, 'weight_trend');
      expect(full.updatedAt, DateTime.utc(2026, 10, 12, 8, 16, 2, 500));
      expect(full.messages.map((message) => message.role), [
        CoachMessageRole.user,
        CoachMessageRole.assistant,
      ]);
      expect(list.first.contextKind, isNull);
      expect(undecodable, ['users/$uid/coach_chats/bad']);
    });

    test('logs an undecodable chat by default', () async {
      await chats().doc('bad').set({'id': 'bad'});

      final repository = CoachRepository(
        firestore: firestore,
        users: users,
        coachChat: (_, {chatId, context, regenerate = false}) =>
            const Stream.empty(),
      );

      expect(await repository.watchChats(uid).first, isEmpty);
    });
  });

  test('watchChat follows one chat: null until it exists, and when it does '
      'not decode', () async {
    final chat = subject().watchChat(uid, '2026-10-15');
    final seen = expectLater(
      chat.map((chat) => chat?.day),
      emitsInOrder([null, '2026-10-12', null]),
    );
    await pumpEventQueue();
    await chats().doc('2026-10-15').set(storedFixture('coach_chat', 'full'));
    await pumpEventQueue();
    await chats().doc('2026-10-15').set({'id': 'bad'});
    await seen;
    expect(undecodable, ['users/$uid/coach_chats/2026-10-15']);
  });

  test('deleteChat deletes the one chat', () async {
    await chats().doc('a').set(storedFixture('coach_chat', 'full'));
    await chats().doc('b').set(storedFixture('coach_chat', 'minimal'));

    await subject().deleteChat(uid, 'a');

    expect((await chats().get()).docs.map((doc) => doc.id), ['b']);
  });

  group('consent', () {
    test('is off until given, and stamped when given', () async {
      final repository = subject();
      expect(await repository.watchConsent(uid).first, isFalse);

      await repository.giveConsent(uid);

      expect(await repository.watchConsent(uid).first, isTrue);
      final settings = await users.watchPrivateSettings(uid).first;
      expect(settings?.coachConsentAt, now);
    });

    test(
      'withdrawing writes false, keeps the stamp and deletes every chat',
      () async {
        final repository = subject();
        await repository.giveConsent(uid);
        await chats().doc('a').set(storedFixture('coach_chat', 'full'));
        await chats().doc('b').set(storedFixture('coach_chat', 'minimal'));

        await repository.withdrawConsent(uid);

        final settings = await users.watchPrivateSettings(uid).first;
        expect(settings?.coachConsent, isFalse);
        expect(settings?.coachConsentAt, now);
        expect((await chats().get()).docs, isEmpty);
      },
    );

    test('stamps the time in UTC by default', () async {
      await CoachRepository(
        firestore: firestore,
        users: users,
        coachChat: (_, {chatId, context, regenerate = false}) =>
            const Stream.empty(),
      ).giveConsent(uid);

      final settings = await users.watchPrivateSettings(uid).first;
      expect(settings?.coachConsentAt?.isUtc, isTrue);
    });
  });

  group('send', () {
    test('passes the message, chat and context to coachChat', () async {
      final events = await subject()
          .send(uid, 'Hi', chatId: 'chat-1', context: CoachContext.today)
          .toList();

      expect((events.single as CoachText).text, 'hi');
      expect(sent.single, ('Hi', 'chat-1', CoachContext.today, false));
    });

    test('passes regenerate to coachChat', () async {
      await subject()
          .send(uid, 'Hi', chatId: 'c', regenerate: true)
          .drain<void>();

      expect(sent.single, ('Hi', 'c', null, true));
    });

    test(
      "keeps each user's remaining count, none on the daily limit",
      () async {
        var refusal = CoachFailure.dailyLimitReached;
        final repository = subject(
          coachChat: (message, {chatId, context, regenerate = false}) =>
              message == 'ok'
              ? Stream.value(
                  const CoachFinished(
                    chatId: 'c',
                    messageId: 'm',
                    text: 'a',
                    remainingToday: 49,
                  ),
                )
              : Stream.error(CoachException(refusal)),
        );
        expect(repository.remainingToday(uid), isNull);

        await repository.send(uid, 'ok').drain<void>();
        expect(repository.remainingToday(uid), 49);
        expect(repository.remainingToday('someone-else'), isNull);

        refusal = CoachFailure.unavailable;
        await expectLater(
          repository.send(uid, 'no'),
          emitsError(_failure(CoachFailure.unavailable)),
        );
        expect(repository.remainingToday(uid), 49);

        refusal = CoachFailure.dailyLimitReached;
        await expectLater(
          repository.send(uid, 'no'),
          emitsError(_failure(CoachFailure.dailyLimitReached)),
        );
        expect(repository.remainingToday(uid), 0);
      },
    );
  });

  group('staging', () {
    late CoachRepository repository;

    setUp(() async {
      repository = await inMemoryCoachRepository(
        firestore: FakeFirebaseFirestore(),
        users: users,
        now: now,
      );
    });

    test('holds the sample chat for the sample user', () async {
      final list = await repository.watchChats(sampleUserId).first;

      expect(list.single.title, 'Why has my weight stalled?');
      expect(list.single.contextKind, 'weight_trend');
      expect(
        list.single.updatedAt,
        now.subtract(const Duration(hours: 23, minutes: 59)),
      );
      expect(list.single.messages, hasLength(2));
      final [block, ...] = list.single.messages.last.blocks!;
      expect(CoachComponent.of(block), isA<CoachTrendChart>());
    });

    test('shows blocks every component can draw, for every screen', () {
      for (final kind in [null, ...CoachContextKind.values]) {
        for (final exerciseId in [null, 'bench']) {
          final blocks = stagingCoachBlocks(
            kind,
            messageId: 'm',
            now: now,
            exerciseId: exerciseId,
            exerciseName: 'Bench',
          );
          expect(blocks, isNotEmpty);
          expect(blocks.map((block) => block.surfaceId), [
            for (var n = 0; n < blocks.length; n++) 'm-$n',
          ]);
          for (final block in blocks) {
            expect(CoachComponent.of(block), isNotNull, reason: block.kind);
          }
        }
      }
    });

    test('refuses until consent is given', () async {
      await expectLater(
        repository.send(sampleUserId, 'Hi'),
        emitsError(_failure(CoachFailure.consentRequired)),
      );
    });

    group('once consent is given', () {
      late CoachChatCall coachChat;

      setUp(() async {
        await users.mergePrivateSettings(
          sampleUserId,
          const PrivateUserSettings(coachConsent: true),
        );
        coachChat = stagingCoachChat(
          firestore: firestore,
          users: users,
          uid: sampleUserId,
          now: () => now,
          wordDelay: Duration.zero,
        );
      });

      test('streams word by word, then saves a new chat as the function '
          'does', () async {
        final events = await coachChat(
          'How am I doing?',
          context: CoachContext.today,
        ).toList();

        final finished = events.last as CoachFinished;
        final words = events.whereType<CoachText>().map((e) => e.text).join();
        expect(words.trim(), finished.text);
        expect(finished.remainingToday, 49);
        final stored = (await chats(
          sampleUserId,
        ).doc(finished.chatId).get()).data()!;
        // Not a day chat: no day.
        expect(
          stored.keys.toSet(),
          {...CoachChatKeys.all}..remove(CoachChatKeys.day),
        );
        final chat = (await CoachRepository(
          firestore: firestore,
          users: users,
          coachChat: coachChat,
        ).watchChats(sampleUserId).first).single;
        expect(chat.title, 'How am I doing?');
        expect(chat.contextKind, 'today');
        expect(chat.updatedAt, now);
        expect(chat.messages.map((m) => (m.role, m.text)), [
          (CoachMessageRole.user, 'How am I doing?'),
          (CoachMessageRole.assistant, finished.text),
        ]);
        expect(chat.messages.last.id, finished.messageId);
        final shown = [
          for (final event in events)
            if (event is CoachBlockShown) event.block.surfaceId,
        ];
        expect(shown, isNotEmpty);
        expect(finished.blocks.map((b) => b.surfaceId), shown);
        expect(chat.messages.last.blocks!.map((b) => b.surfaceId), shown);
        expect(chat.messages.first.blocks, isNull);
      });

      test(
        'says what it reads, then shows each block after a status',
        () async {
          final events = await coachChat(
            'Hi',
            context: const CoachContext(kind: CoachContextKind.weightTrend),
          ).toList();

          expect((events.first as CoachStatus).tool, 'get_body_metrics');
          for (var i = 0; i < events.length; i++) {
            if (events[i] is CoachBlockShown) {
              expect((events[i - 1] as CoachStatus).tool, 'show_block');
            }
          }
          final today = await coachChat('Hi').first;
          expect((today as CoachStatus).tool, 'get_workout_history');
        },
      );

      test('regenerating replaces the last exchange when it is that '
          'question', () async {
        final first = await coachChat('First').last as CoachFinished;
        final chatId = first.chatId;
        await coachChat('Second', chatId: chatId).drain<void>();

        Future<List<Object?>> texts() async => [
          for (final message
              in (await chats(
                    sampleUserId,
                  ).doc(chatId).get()).data()![CoachChatKeys.messages]!
                  as List<Object?>)
            (message! as Map)[CoachMessageKeys.text],
        ];

        // Not the last question: answered as a new one.
        await coachChat(
          'First',
          chatId: chatId,
          regenerate: true,
        ).drain<void>();
        expect(await texts(), hasLength(6));

        final again =
            await coachChat('First', chatId: chatId, regenerate: true).last
                as CoachFinished;
        expect(await texts(), [
          'First',
          first.text,
          'Second',
          first.text,
          'First',
          again.text,
        ]);
        final ids = [
          for (final message
              in (await chats(
                    sampleUserId,
                  ).doc(chatId).get()).data()![CoachChatKeys.messages]!
                  as List<Object?>)
            (message! as Map)[CoachMessageKeys.id],
        ];
        expect(ids.last, again.messageId);
        expect(ids, isNot(contains('$chatId-3')));
      });

      test('continues a chat, keeping its title, start and context', () async {
        final first = await coachChat('First').last as CoachFinished;
        final second =
            await coachChat('Second', chatId: first.chatId).last
                as CoachFinished;

        expect(second.chatId, first.chatId);
        expect(second.remainingToday, 48);
        final stored = (await chats(
          sampleUserId,
        ).doc(first.chatId).get()).data()!;
        expect(stored[CoachChatKeys.title], 'First');
        expect(stored[CoachChatKeys.contextKind], isNull);
        expect(stored[CoachChatKeys.messages], hasLength(4));
      });

      test('makes a day chat on its first message, today or yesterday, and '
          'refuses an older day', () async {
        for (final day in ['2026-10-15', '2026-10-14']) {
          final finished = await coachChat('Hi', chatId: day).last;
          expect((finished as CoachFinished).chatId, day);
          final stored = (await chats(sampleUserId).doc(day).get()).data()!;
          expect(stored[CoachChatKeys.day], day);
        }
        await coachChat('Again', chatId: '2026-10-15').drain<void>();
        expect(
          (await chats(
            sampleUserId,
          ).doc('2026-10-15').get()).data()![CoachChatKeys.messages],
          hasLength(4),
        );

        await expectLater(
          coachChat('Hi', chatId: '2026-10-13'),
          emitsError(_failure(CoachFailure.pastDay)),
        );
      });

      test('refuses a chat that does not exist', () async {
        await expectLater(
          coachChat('Hi', chatId: 'gone'),
          emitsError(_failure(CoachFailure.failed)),
        );
      });

      test('stops at 50 messages a day', () async {
        for (var i = 0; i < 50; i++) {
          await coachChat('Hi').drain<void>();
        }

        await expectLater(
          coachChat('Hi'),
          emitsError(_failure(CoachFailure.dailyLimitReached)),
        );
      });

      test('answers some screens in their own terms', () async {
        final today = await coachChat('Hi').last as CoachFinished;
        final trend =
            await coachChat(
                  'Hi',
                  context: const CoachContext(
                    kind: CoachContextKind.weightTrend,
                  ),
                ).last
                as CoachFinished;

        expect(trend.text, isNot(today.text));
        expect(trend.text, contains('trend weight'));
      });

      test('answers by default after a short pause per word', () async {
        final events = await stagingCoachChat(
          firestore: firestore,
          users: users,
          uid: sampleUserId,
        )('Hi').toList();

        expect(events.last, isA<CoachFinished>());
      });
    });
  });
}
