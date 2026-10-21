import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFunctions extends Mock implements FirebaseFunctions;

class _MockCallable extends Mock implements HttpsCallable;

class _MockResult extends Mock implements HttpsCallableResult<Object?>;

HttpsCallableResult<Object?> _result(Object? data) {
  final result = _MockResult();
  when(() => result.data).thenReturn(data);
  return result;
}

FirebaseFunctionsException _refusal(String code, [String? reason]) =>
    FirebaseFunctionsException(
      message: code,
      code: code,
      details: reason == null ? null : {'reason': reason},
    );

Matcher _failure(CoachFailure failure) =>
    isA<CoachException>().having((error) => error.failure, 'failure', failure);

const Map<String, Object?> _finishedData = {
  'chatId': 'chat-1',
  'messageId': 'm-2',
  'text': 'Hello there',
  'remainingToday': 49,
};

extension<T> on Stream<T> {
  Stream<T> followedBy(Exception error) async* {
    yield* this;
    throw error;
  }
}

void main() {
  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  late _MockFunctions functions;
  late _MockCallable callable;
  late Stream<StreamResponse<Object?, Object?>> Function() stream;
  late Future<HttpsCallableResult<Object?>> Function() call;

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    stream = () => const Stream.empty();
    call = () async => _result(_finishedData);
    when(
      () =>
          functions.httpsCallable('coachChat', options: any(named: 'options')),
    ).thenReturn(callable);
    when(() => callable.stream<Object?, Object?>(any<Object?>()))
        .thenAnswer((_) => stream());
    when(() => callable.call<Object?>(any<Object?>()))
        .thenAnswer((_) => call());
  });

  Stream<CoachStreamEvent> send({String? chatId, CoachContext? context}) =>
      firebaseCoachChat(functions)('Hi', chatId: chatId, context: context);

  test('calls coachChat allowing 120 seconds', () {
    firebaseCoachChat(functions);

    final options =
        verify(
              () => functions.httpsCallable(
                'coachChat',
                options: captureAny(named: 'options'),
              ),
            ).captured.single
            as HttpsCallableOptions;
    expect(options.timeout, const Duration(seconds: 120));
  });

  group('request', () {
    Future<Object?> sent({String? chatId, CoachContext? context}) async {
      stream = () => Stream.value(Result(_result(_finishedData)));
      await send(chatId: chatId, context: context).drain<void>();
      return verify(
        () => callable.stream<Object?, Object?>(captureAny<Object?>()),
      ).captured.single;
    }

    test('leaves out what is absent', () async {
      expect(await sent(), {'message': 'Hi', 'ui': 1});
      expect(await sent(context: CoachContext.today), {
        'message': 'Hi',
        'context': {'kind': 'today'},
        'ui': 1,
      });
    });

    test('sends the chat and the whole context, less its title', () async {
      expect(
        await sent(
          chatId: 'chat-1',
          context: const CoachContext(
            kind: CoachContextKind.nutritionDay,
            id: 'x',
            date: '2026-10-15',
            title: 'Thursday',
          ),
        ),
        {
          'chatId': 'chat-1',
          'message': 'Hi',
          'context': {'kind': 'nutrition_day', 'id': 'x', 'date': '2026-10-15'},
          'ui': 1,
        },
      );
    });
  });

  test('streams the text, then the saved result, and stops there', () async {
    stream = () => Stream.fromIterable([
      Chunk({'text': 'Hello '}),
      Chunk({'text': 'there'}),
      Result(_result({..._finishedData, 'remainingToday': 48.0})),
      Chunk({'text': 'ignored'}),
    ]);

    final events = await send().toList();

    expect(events, hasLength(3));
    expect((events[0] as CoachText).text, 'Hello ');
    expect((events[1] as CoachText).text, 'there');
    final finished = events[2] as CoachFinished;
    expect(finished.chatId, 'chat-1');
    expect(finished.messageId, 'm-2');
    expect(finished.text, 'Hello there');
    expect(finished.remainingToday, 48);
    verifyNever(() => callable.call<Object?>(any<Object?>()));
  });

  group('blocks', () {
    /// A recorded stream (compound_models' test/fixtures/coach/).
    Map<String, Object?> recorded(String name) => jsonDecode(
      File('../compound_models/test/fixtures/coach/$name').readAsStringSync(),
    ) as Map<String, Object?>;

    for (final name in ['weight_stream.json', 'nutrition_stream.json']) {
      test(
        '$name: text, then blocks in order, then the result with them',
        () async {
          final fixture = recorded(name);
          final chunks = fixture['chunks']! as List<Object?>;
          final request = fixture['request']! as Map<String, Object?>;
          stream = () => Stream.fromIterable([
            for (final chunk in chunks) Chunk(chunk),
            Result(_result(fixture['result'])),
          ]);

          final context = request['context']! as Map<String, Object?>;
          final events = await firebaseCoachChat(functions)(
            request['message']! as String,
            context: CoachContext(
              kind: CoachContextKind.values.firstWhere(
                (kind) => kind.value == context['kind'],
              ),
              date: context['date'] as String?,
            ),
          ).toList();

          expect(
            verify(
              () => callable.stream<Object?, Object?>(captureAny<Object?>()),
            ).captured.single,
            request,
          );
          final expected = [
            for (final chunk in chunks.cast<Map<String, Object?>>())
              if (chunk['block'] case final Map<String, Object?> block)
                block['surfaceId']
              else
                chunk['text'],
          ];
          expect(
            [
              for (final event in events)
                switch (event) {
                  CoachText(:final text) => text,
                  CoachBlockShown(:final block) => block.surfaceId,
                  CoachFinished() => null,
                },
            ],
            [...expected, null],
          );
          final finished = events.last as CoachFinished;
          expect(finished.blocks.map((block) => block.surfaceId), [
            for (final event in events)
              if (event is CoachBlockShown) event.block.surfaceId,
          ]);
          expect(finished.blocks.first.messages, isNotEmpty);
          verifyNever(() => callable.call<Object?>(any<Object?>()));
        },
      );
    }

    test(
      'one that does not decode is dropped, and the answer stands',
      () async {
        stream = () => Stream.fromIterable([
          Chunk({'text': 'Hi', 'block': 'not a block'}),
          Chunk({
            'text': '',
            'block': {'surfaceId': 's'},
          }),
          Result(_result(_finishedData)),
        ]);

        final events = await send().toList();

        expect(events, hasLength(2));
        expect((events.first as CoachText).text, 'Hi');
        expect((events.last as CoachFinished).blocks, isEmpty);
        verifyNever(() => callable.call<Object?>(any<Object?>()));
      },
    );

    group('a reply that arrives whole', () {
      /// The weight stream's blocks as the chat stores them, in the result.
      List<Map<String, Object?>> storedBlocks() => [
        for (final chunk
            in (recorded('weight_stream.json')['chunks']! as List)
                .cast<Map<String, Object?>>())
          if (chunk['block'] case final Map<String, Object?> block)
            {
              for (final MapEntry(:key, :value) in block.entries)
                if (key != 'asOf') key: value,
              'as_of': block['asOf'],
            },
      ];

      Future<List<String>> finishedBlocks(Object? blocks) async {
        call = () async => _result({..._finishedData, 'blocks': blocks});
        final finished = await send().single as CoachFinished;
        return [for (final block in finished.blocks) block.surfaceId];
      }

      test('shows the blocks its result carries', () async {
        final blocks = storedBlocks();
        expect(blocks, hasLength(greaterThan(1)));

        expect(await finishedBlocks(blocks), [
          for (final block in blocks) block['surfaceId'],
        ]);
      });

      test('drops one that does not decode', () async {
        final [first, ...] = storedBlocks();

        expect(
          await finishedBlocks([
            'not a block',
            first,
            {'surfaceId': 's'},
          ]),
          [first['surfaceId']],
        );
      });

      test('shows none when the result carries none', () async {
        expect(await finishedBlocks(null), isEmpty);
        expect(await finishedBlocks('not a list'), isEmpty);
        call = () async => _result(_finishedData);
        expect((await send().single as CoachFinished).blocks, isEmpty);
      });
    });

    test('a streamed answer keeps its streamed blocks, once', () async {
      final fixture = recorded('weight_stream.json');
      final chunks = fixture['chunks']! as List<Object?>;
      stream = () => Stream.fromIterable([
        for (final chunk in chunks) Chunk(chunk),
        Result(
          _result({
            ...fixture['result']! as Map<String, Object?>,
            'blocks': [
              for (final chunk in chunks.cast<Map<String, Object?>>())
                if (chunk['block'] case final Map<String, Object?> block)
                  {...block, 'as_of': block['asOf']},
            ],
          }),
        ),
      ]);

      final events = await send().toList();

      expect((events.last as CoachFinished).blocks.map((b) => b.surfaceId), [
        for (final event in events)
          if (event is CoachBlockShown) event.block.surfaceId,
      ]);
    });

    test(
      'a block alone means it was answering: a drop is not asked again',
      () async {
        final block = (recorded('weight_stream.json')['chunks']! as List)[2];
        stream = () =>
            Stream<StreamResponse<Object?, Object?>>.value(Chunk(block))
                .followedBy(PlatformException(code: 'firebase_functions'));

        await expectLater(
          send(),
          emitsInOrder([
            isA<CoachBlockShown>(),
            emitsError(_failure(CoachFailure.unavailable)),
          ]),
        );
        verifyNever(() => callable.call<Object?>(any<Object?>()));
      },
    );
  });

  group('a refusal the stream reports with its code', () {
    for (final (code, reason, failure) in [
      ('failed-precondition', 'consent', CoachFailure.consentRequired),
      ('failed-precondition', null, CoachFailure.failed),
      ('permission-denied', 'premium', CoachFailure.premiumRequired),
      ('permission-denied', null, CoachFailure.failed),
      ('resource-exhausted', 'quota', CoachFailure.dailyLimitReached),
      ('resource-exhausted', 'burst', CoachFailure.tooManyAtOnce),
      ('unavailable', null, CoachFailure.unavailable),
      ('deadline-exceeded', null, CoachFailure.unavailable),
      ('internal', null, CoachFailure.unavailable),
      ('cancelled', null, CoachFailure.unavailable),
      ('not-found', null, CoachFailure.failed),
      ('unauthenticated', null, CoachFailure.failed),
    ]) {
      test('$code ($reason) is ${failure.name}, asked once', () async {
        stream = () => Stream.error(_refusal(code, reason));

        await expectLater(send(), emitsError(_failure(failure)));
        verifyNever(() => callable.call<Object?>(any<Object?>()));
      });
    }
  });

  group('when the stream cannot say why, asks once more without it', () {
    test('and answers whole when the stream ended with no result', () async {
      stream = () => const Stream.empty();

      final events = await send().toList();

      expect((events.single as CoachFinished).text, 'Hello there');
    });

    test('and reads the refusal it carries', () async {
      stream = () => Stream.error(_refusal('unknown'));
      call = () => Future.error(_refusal('failed-precondition', 'consent'));

      await expectLater(
        send(),
        emitsError(_failure(CoachFailure.consentRequired)),
      );
      verify(() => callable.call<Object?>({'message': 'Hi', 'ui': 1}))
          .called(1);
    });

    test('after a platform error or an unreadable chunk', () async {
      for (final failing in [
        Stream<StreamResponse<Object?, Object?>>.error(
          PlatformException(code: 'firebase_functions'),
        ),
        Stream<StreamResponse<Object?, Object?>>.value(Chunk('not a map')),
      ]) {
        stream = () => failing;

        expect(await send().last, isA<CoachFinished>());
      }
    });

    test('and is unavailable when that fails without a code, or answers '
        'something unreadable', () async {
      for (final failing in [
        () => Future<HttpsCallableResult<Object?>>.error(StateError('x')),
        () async => _result({'chatId': 'chat-1'}),
        () => Future<HttpsCallableResult<Object?>>.error(_refusal('unknown')),
      ]) {
        call = failing;

        await expectLater(
          send(),
          emitsError(_failure(CoachFailure.unavailable)),
        );
      }
    });
  });

  group('once text has arrived, never asks again', () {
    for (final (name, failing) in [
      (
        'when the stream ends with no result',
        () => Stream<StreamResponse<Object?, Object?>>.value(
          Chunk({'text': 'Hel'}),
        ),
      ),
      (
        'when it fails without a code',
        () => Stream<StreamResponse<Object?, Object?>>.fromIterable([
          Chunk({'text': 'Hel'}),
        ]).followedBy(PlatformException(code: 'firebase_functions')),
      ),
    ]) {
      test(name, () async {
        stream = failing;

        await expectLater(
          send(),
          emitsInOrder([
            isA<CoachText>(),
            emitsError(_failure(CoachFailure.unavailable)),
          ]),
        );
        verifyNever(() => callable.call<Object?>(any<Object?>()));
      });
    }
  });

  test('a failure describes itself', () {
    expect(
      const CoachException(CoachFailure.failed, 'why').toString(),
      'CoachException(failed, why)',
    );
  });

  test('every context kind has its wire value', () {
    expect(
      [for (final kind in CoachContextKind.values) kind.value],
      [
        'today',
        'weight_trend',
        'exercise',
        'session',
        'check_in',
        'nutrition_day',
        'weekly_review',
        'mesocycle',
        'expenditure',
        'muscle_group',
      ],
    );
  });
}
