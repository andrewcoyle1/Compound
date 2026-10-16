import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';

const _workout = IntentWorkout(id: 'w1', name: 'Push Day');

class _Handler implements AppIntentHandler {
  bool? pounds;
  bool browsed = false;

  @override
  Future<List<IntentWorkout>> workouts() async => [_workout];

  @override
  Future<String> startWorkout(String id) async {
    if (id != _workout.id) throw const AppIntentRefusal('Not found.');
    return 'Starting Push Day.';
  }

  @override
  Future<String> logWeight(double value, {bool? pounds}) async {
    this.pounds = pounds;
    return 'Logged $value.';
  }

  @override
  Future<({int count, String sentence})> workoutsThisWeek() async =>
      (count: 2, sentence: 'Two.');

  @override
  Future<({IntentWorkout? workout, String sentence})> todaysWorkout() async =>
      (workout: _workout, sentence: 'Push Day.');

  @override
  Future<void> browseRecipes() async => browsed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(MethodChannelAppIntentsRepository.channelName);

  group(MethodChannelAppIntentsRepository, () {
    late List<MethodCall> sent;

    setUp(() {
      sent = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        sent.add(call);
        return null;
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });

    Future<Object?> ask(String method, [Object? arguments]) async {
      ByteData? reply;
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall(method, arguments)),
        (data) => reply = data,
      );
      // Not implemented answers nothing.
      if (reply == null) return null;
      return channel.codec.decodeEnvelope(reply!);
    }

    test('answers each intent from the handler', () async {
      final handler = _Handler();
      MethodChannelAppIntentsRepository().setHandler(handler);
      await pumpEventQueue();
      expect(sent.single.method, 'ready');

      expect(await ask('workouts'), {
        'workouts': [
          {'id': 'w1', 'name': 'Push Day'},
        ],
      });
      expect(await ask('startWorkout', {'id': 'w1'}), {
        'sentence': 'Starting Push Day.',
      });
      expect(await ask('logWeight', {'value': 70, 'unit': 'pounds'}), {
        'sentence': 'Logged 70.0.',
      });
      expect(handler.pounds, isTrue);
      await ask('logWeight', {'value': 70.5});
      expect(handler.pounds, isNull);
      expect(await ask('workoutsThisWeek'), {'count': 2, 'sentence': 'Two.'});
      expect(await ask('todaysWorkout'), {
        'workout': {'id': 'w1', 'name': 'Push Day'},
        'sentence': 'Push Day.',
      });
      expect(await ask('browseRecipes'), isEmpty);
      expect(handler.browsed, isTrue);
    });

    test("passes a refusal on as Siri's sentence", () async {
      MethodChannelAppIntentsRepository().setHandler(_Handler());
      await expectLater(
        ask('startWorkout', {'id': 'gone'}),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message,
            'message',
            'Not found.',
          ),
        ),
      );
      expect(await ask('dance'), isNull);
    });

    test('stops, and does nothing off iOS', () async {
      final repository = MethodChannelAppIntentsRepository()
        ..setHandler(_Handler())
        ..setHandler(null);
      await pumpEventQueue();
      sent.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      repository.setHandler(_Handler());
      await pumpEventQueue();
      expect(sent, isEmpty);
    });
  });

  test('$IntentWorkout is a value', () {
    expect(_workout.props, ['w1', 'Push Day']);
  });

  test('$FakeAppIntentsRepository keeps the handler', () {
    final handler = _Handler();
    final repository = FakeAppIntentsRepository()..setHandler(handler);
    expect(repository.handler, handler);
  });
}
