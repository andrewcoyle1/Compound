import 'package:material_ui/material_ui.dart';

/// {@template app_motion}
/// One of the app's animation timings, each a duration and a curve.
///
/// - [press]: a control shrinking under the finger and gliding back.
/// - [quick]: selection, toggles, icon swaps, small state flips.
/// - [standard]: something on screen changing in place: moving, resizing
///   or morphing.
/// - [move]: something entering, or travelling to a new place (a snack bar
///   rising, a scroll to a month).
/// - [emphasis]: a moment worth celebrating (a set completed, a PR).
/// - [progress]: rings, bars and charts filling to a value.
///
/// Everything a person causes answers in 300 ms or less; only moves across
/// the screen take longer, and only [emphasis] and [progress] reach past
/// 400 ms.
///
/// Leaving is quicker and quieter than arriving: an exit runs for
/// [exitDurationOf] on [exitCurve].
///
/// Read the duration through [durationOf], never [duration] directly: it
/// drops to zero when the user has asked the system to reduce motion.
/// {@endtemplate}
enum AppMotion {
  /// A control pressed: it scales down and glides back on release.
  press(Duration(milliseconds: 120), _easeOut),

  /// Selection, toggles, icon swaps, small state flips.
  quick(Duration(milliseconds: 200), _easeOut),

  /// Something on screen moving, resizing or morphing in place.
  standard(Duration(milliseconds: 300), _easeInOut),

  /// Something entering, or travelling to a new place.
  move(Duration(milliseconds: 350), _easeOut),

  /// A moment worth celebrating.
  emphasis(Duration(milliseconds: 500), Curves.easeOutBack),

  /// Rings, bars and charts filling to a value.
  progress(Duration(seconds: 1), Curves.easeOut);

  new(this.duration, this.curve);

  /// The full-motion duration.
  final Duration duration;

  /// The easing curve.
  final Curve curve;

  /// Fast at the start and settling at the end, so a response feels
  /// immediate: for anything appearing or answering a touch.
  static const Curve _easeOut = Cubic(0.32, 0.72, 0, 1);

  /// Speeds up and slows down, for something that stays on screen.
  static const Curve _easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// How everything leaves: slow at first, then out of the way.
  static const Curve exitCurve = Cubic(0.55, 0, 1, 0.45);

  /// An exit's share of its entrance.
  static const double exitFactor = 0.75;

  /// [duration], or zero when the platform asks for reduced motion
  /// (`MediaQuery.disableAnimations`).
  Duration durationOf(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

  /// How long the same element takes to leave: three quarters of
  /// [durationOf], so zero under reduced motion too.
  Duration exitDurationOf(BuildContext context) =>
      durationOf(context) * exitFactor;
}
