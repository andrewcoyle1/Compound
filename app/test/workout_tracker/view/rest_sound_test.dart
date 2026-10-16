import 'package:compound/workout_tracker/view/rest_sound.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(RestSound, () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(RestSound.channel, null));

    test('asks the platform for the rest-complete sound', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(RestSound.channel, (call) async {
        calls.add(call.method);
        return null;
      });
      await RestSound.play();
      expect(calls, ['restComplete']);
    });

    test('is silent where the platform has no channel or fails', () async {
      await expectLater(RestSound.play(), completes);
      messenger.setMockMethodCallHandler(
        RestSound.channel,
        (_) async => throw PlatformException(code: 'no-audio'),
      );
      await expectLater(RestSound.play(), completes);
    });
  });
}
