import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';

/// The chime a rest makes as it runs out in the app (Swift's
/// `SoundEffectFile.restComplete`).
abstract interface class RestChime {
  /// Plays it.
  Future<void> play();
}

/// {@template soloud_rest_chime}
/// [RestChime] through `flutter_soloud`: `assets/sounds/rest_chime.wav`,
/// synthesised by `scripts/rest-chime.py`. The engine starts on the first
/// chime and stops [idle] after the last, rather than running for a whole
/// workout.
///
/// flutter_soloud leaves the iOS audio session to the app, which sets it to
/// ambient (`AppDelegate.swift`): the chime mixes with other audio and
/// follows the silent switch. Android plays it on the media stream, so it
/// does not follow the ringer mode.
/// {@endtemplate}
class SoloudRestChime implements RestChime {
  /// {@macro soloud_rest_chime}
  new([SoLoud? soloud]) : _soloud = soloud ?? SoLoud.instance;

  /// The bundled sound.
  static const asset =
      'packages/notifications_repository/assets/sounds/rest_chime.wav';

  /// How long the engine stays up after a chime.
  static const idle = Duration(seconds: 5);

  final SoLoud _soloud;
  AudioSource? _source;
  Timer? _release;

  @override
  Future<void> play() async {
    _release?.cancel();
    if (!_soloud.isInitialized) await _soloud.init();
    _soloud.play(_source ??= await _soloud.loadAsset(asset));
    _release = Timer(idle, () {
      // Stopping the engine frees the loaded sound too.
      _source = null;
      unawaited(_soloud.deinitAsync());
    });
  }
}
