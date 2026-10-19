import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

/// One of the seven haptics the app plays, by meaning
/// (ui-contract.md, rule 4).
enum AppHaptic {
  /// A save, log, completion or finish.
  success(HapticsType.success, HapticFeedback.successNotification),

  /// A save or action that failed.
  error(HapticsType.error, HapticFeedback.errorNotification),

  /// Something needing attention, such as a rest timer running out.
  warning(HapticsType.warning, HapticFeedback.warningNotification),

  /// A picker, segment or option changing.
  selection(HapticsType.selection, HapticFeedback.selectionClick),

  /// A light impact.
  light(HapticsType.light, HapticFeedback.lightImpact),

  /// A medium impact, such as a swipe passing the point where it acts.
  medium(HapticsType.medium, HapticFeedback.mediumImpact),

  /// A heavy impact.
  heavy(HapticsType.heavy, HapticFeedback.heavyImpact);

  new(this._type, this._fallback);

  final HapticsType _type;

  /// Flutter's own haptic, for a device `haptic_feedback` cannot drive.
  final Future<void> Function() _fallback;
}

/// {@template app_haptics}
/// The app's haptics. Feature code plays these, never Flutter's
/// `HapticFeedback`.
///
/// Played through `haptic_feedback`, which gives Android the iOS patterns
/// (a success is two rising pulses, an error four) instead of a single
/// buzz. Where the device has no vibrator, or the plugin is missing, it
/// falls back to Flutter's `HapticFeedback`.
/// {@endtemplate}
abstract final class AppHaptics {
  /// A save, log, completion or finish.
  static Future<void> success() => play(AppHaptic.success);

  /// A save or action that failed.
  static Future<void> error() => play(AppHaptic.error);

  /// Something needing attention.
  static Future<void> warning() => play(AppHaptic.warning);

  /// A picker, segment or option changing.
  static Future<void> selection() => play(AppHaptic.selection);

  /// A light impact.
  static Future<void> light() => play(AppHaptic.light);

  /// A medium impact.
  static Future<void> medium() => play(AppHaptic.medium);

  /// A heavy impact.
  static Future<void> heavy() => play(AppHaptic.heavy);

  /// Receives each haptic instead of the device, in tests: set it to record
  /// them (`AppHaptics.debugPlay = haptics.add`), and back to null after.
  @visibleForTesting
  static void Function(AppHaptic haptic)? debugPlay;

  static Future<bool>? _canVibrate;

  /// Forgets whether the device can vibrate, so a test can ask again.
  @visibleForTesting
  static void debugReset() => _canVibrate = null;

  /// Plays [haptic].
  static Future<void> play(AppHaptic haptic) async {
    final fake = debugPlay;
    if (fake != null) return fake(haptic);
    try {
      if (await (_canVibrate ??= Haptics.canVibrate())) {
        // Touch usage, so Android 13 and later follow the user's touch
        // feedback setting.
        return await Haptics.vibrate(haptic._type, usage: HapticsUsage.touch);
      }
    } on Exception {
      // No plugin (a test, an unsupported platform) or a vibrator error:
      // Flutter's haptic below still plays.
    }
    await haptic._fallback();
  }
}
