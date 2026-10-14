import 'package:material_ui/material_ui.dart';

/// {@template app_motion}
/// One of the four animation curves.
///
/// - [quick]: selection, toggles, small state flips.
/// - [standard]: content appearing, moving or resizing.
/// - [emphasis]: a moment worth celebrating (a set completed, a PR).
/// - [progress]: rings and bars filling to a value.
///
/// Read the duration through [durationOf], never [duration] directly: it
/// drops to zero when the user has asked the system to reduce motion.
/// {@endtemplate}
enum AppMotion {
  /// Selection, toggles, small state flips.
  quick(Duration(milliseconds: 200), Curves.easeOutCubic),

  /// Content appearing, moving or resizing.
  standard(Duration(milliseconds: 350), Curves.easeInOutCubic),

  /// A moment worth celebrating.
  emphasis(Duration(milliseconds: 500), Curves.easeOutBack),

  /// Rings and bars filling to a value.
  progress(Duration(seconds: 1), Curves.easeOut);

  new(this.duration, this.curve);

  /// The full-motion duration.
  final Duration duration;

  /// The easing curve.
  final Curve curve;

  /// [duration], or zero when the platform asks for reduced motion
  /// (`MediaQuery.disableAnimations`).
  Duration durationOf(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
