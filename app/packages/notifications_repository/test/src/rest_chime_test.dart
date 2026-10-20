import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications_repository/notifications_repository.dart';

class _MockSoLoud extends Mock implements SoLoud {
  @override
  void setInaudibleBehavior(SoundHandle handle, bool mustTick, bool kill) {}
}

class _MockAudioSource extends Mock implements AudioSource;

void main() {
  group(SoloudRestChime, () {
    late _MockSoLoud soloud;
    late _MockAudioSource source;
    late bool initialized;

    setUpAll(() => registerFallbackValue(_MockAudioSource()));

    setUp(() {
      soloud = _MockSoLoud();
      source = _MockAudioSource();
      initialized = false;
      when(() => soloud.isInitialized).thenAnswer((_) => initialized);
      when(soloud.init).thenAnswer((_) async => initialized = true);
      when(() => soloud.loadAsset(SoloudRestChime.asset))
          .thenAnswer((_) async => source);
      when(() => soloud.play(any())).thenReturn(const SoundHandle(1));
      when(soloud.deinitAsync).thenAnswer((_) async => initialized = false);
    });

    test('starts the engine on the first chime and stops it when idle', () {
      fakeAsync((async) {
        final chime = SoloudRestChime(soloud);
        unawaited(chime.play());
        async.flushMicrotasks();
        unawaited(chime.play());
        async.flushMicrotasks();
        verify(soloud.init).called(1);
        verify(() => soloud.loadAsset(SoloudRestChime.asset)).called(1);
        verify(() => soloud.play(source)).called(2);

        async.elapse(SoloudRestChime.idle - const Duration(seconds: 1));
        verifyNever(soloud.deinitAsync);
        async.elapse(const Duration(seconds: 1));
        verify(soloud.deinitAsync).called(1);

        // The next chime starts it again, with the sound reloaded.
        unawaited(chime.play());
        async.flushMicrotasks();
        verify(soloud.init).called(1);
        verify(() => soloud.loadAsset(SoloudRestChime.asset)).called(1);
      });
    });

    test('defaults to the shared engine', () {
      expect(SoloudRestChime.new, returnsNormally);
    });
  });
}
