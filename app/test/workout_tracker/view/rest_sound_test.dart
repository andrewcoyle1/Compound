import 'package:compound/workout_tracker/view/rest_sound.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications_repository/notifications_repository.dart';

class _Chime implements RestChime {
  int plays = 0;
  Error? failure;

  @override
  Future<void> play() async {
    plays++;
    if (failure case final failure?) throw failure;
  }
}

void main() {
  group(RestSound, () {
    late _Chime chime;
    late RestChime original;

    setUp(() {
      original = RestSound.chime;
      RestSound.chime = chime = _Chime();
    });

    tearDown(() => RestSound.chime = original);

    test('plays the rest-complete chime', () async {
      await RestSound.play();
      expect(chime.plays, 1);
    });

    test('is silent when it cannot play', () async {
      chime.failure = StateError('no audio device');
      await expectLater(RestSound.play(), completes);
    });
  });
}
