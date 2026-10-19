import 'package:flutter/foundation.dart';
import 'package:notifications_repository/notifications_repository.dart';

/// The sound a rest makes as it runs out in the app (Swift's
/// `SoundEffectFile.restComplete`): the bundled chime ([SoloudRestChime]),
/// which mixes with whatever is playing and, on iOS, follows the silent
/// switch.
abstract final class RestSound {
  /// What plays it; tests put in a fake.
  @visibleForTesting
  static RestChime chime = SoloudRestChime();

  /// Plays it; a failure (no audio device) is silent.
  static Future<void> play() async {
    try {
      await chime.play();
    } on Object {
      // The sound is a nicety; the haptic and the screen still say it.
    }
  }
}
