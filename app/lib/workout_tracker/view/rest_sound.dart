import 'package:flutter/services.dart';

/// The sound a rest makes as it runs out in the app (Swift's
/// `SoundEffectFile.restComplete`), played by the app's own platform code:
/// iOS system sound 1007, Swift's stand-in while it has no audio file, and
/// Android's default notification sound. Both follow the silent switch or
/// ringer mode and mix with whatever is playing.
abstract final class RestSound {
  /// The app's channel (`MainActivity.kt`, `AppDelegate.swift`).
  static const channel = MethodChannel('com.andrewcoyle.compound/sound');

  /// Plays it; a platform without the channel (a test, a desktop) is
  /// silent.
  static Future<void> play() async {
    try {
      await channel.invokeMethod<void>('restComplete');
    } on MissingPluginException {
      // Nowhere to play it.
    } on PlatformException {
      // The sound is a nicety; the haptic and the screen still say it.
    }
  }
}
