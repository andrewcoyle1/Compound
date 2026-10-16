import 'dart:async';

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
      expect(await sent(), {'message': 'Hi'});
      expect(await sent(context: CoachContext.today), {
        'message': 'Hi',
        'context': {'kind': 'today'},
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
      verify(() => callable.call<Object?>({'message': 'Hi'})).called(1);
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
