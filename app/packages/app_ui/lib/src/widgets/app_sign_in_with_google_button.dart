import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:app_ui/src/widgets/app_sign_in_button.dart';

/// {@template app_sign_in_with_google_button}
/// Google's "Continue with Google" button, drawn as Google's sign-in
/// branding guidelines set out (developers.google.com/identity/
/// branding-guidelines) and as Swift's `SignInWithGoogleButtonView` does:
///
/// - Google's light theme in light mode (white, a #747775 outline, #1F1F1F
///   title) and its dark theme in dark mode (#131314, a #8E918F outline,
///   #E3E3E3 title);
/// - the standard-colour "G" from Google's sign-in button kit, never
///   recoloured;
/// - Google's padding for the platform (iOS 16 / 12 / 16, Android 12 / 10 /
///   12 around the logo and title) and its 20-point logo, scaled up with the
///   button from Google's own height (44 on iOS, 40 on Android).
///
/// It shares [AppSignInWithAppleButton]'s height, capsule shape and title
/// size, so neither is more prominent than the other, as both Apple and
/// Google ask. While [isLoading] a spinner takes the logo and title's place.
/// {@endtemplate}
class AppSignInWithGoogleButton extends StatelessWidget {
  /// {@macro app_sign_in_with_google_button}
  const new({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  /// "Continue with Google", localized. Google recommends that, "Sign in
  /// with Google" or "Sign up with Google".
  final String label;

  /// Called when tapped. `null` disables the button.
  final VoidCallback? onPressed;

  /// Whether sign-in is under way.
  final bool isLoading;

  /// Google's dark fill. A brand colour, not a design token.
  static const darkFill = Color(0xFF131314);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ios = theme.platform == TargetPlatform.iOS;
    final scale = AppSignInButton.height / (ios ? 44 : 40);
    final edge = SizedBox(width: (ios ? 16 : 12) * scale);
    return AppSignInButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      background: dark ? darkFill : Colors.white,
      foreground: dark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F),
      border: BorderSide(
        color: dark ? const Color(0xFF8E918F) : const Color(0xFF747775),
      ),
      leading: [
        edge,
        CustomPaint(
          size: Size.square(20 * scale),
          painter: _GoogleLogoPainter(),
        ),
        SizedBox(width: (ios ? 12 : 10) * scale),
      ],
      trailing: [edge],
    );
  }
}

/// The "G" from Google's sign-in button kit (`signin-assets.zip`, the
/// Android + Web SVGs), in its 20 × 20 box at (10, 10) of the 40-point
/// square button: a sweep of Google's colours and six soft highlights,
/// clipped to the G.
class _GoogleLogoPainter extends CustomPainter {
  static final _g = Path()
    ..moveTo(29.3987, 18.1814)
    ..lineTo(19.9849, 18.1814)
    ..lineTo(19.9849, 22.0445)
    ..lineTo(25.3598, 22.0445)
    ..cubicTo(25.1286, 23.294, 24.4294, 24.3596, 23.3676, 25.0712)
    ..cubicTo(22.4746, 25.6716, 21.3266, 26.0211, 19.9849, 26.0211)
    ..cubicTo(17.3864, 26.0211, 15.1823, 24.2666, 14.3947, 21.9004)
    ..cubicTo(14.1952, 21.2989, 14.0853, 20.6599, 14.0853, 19.9983)
    ..cubicTo(14.0853, 19.3367, 14.1952, 18.6966, 14.3947, 18.0962)
    ..cubicTo(15.1823, 15.7311, 17.3864, 13.9755, 19.9849, 13.9755)
    ..cubicTo(21.4524, 13.9755, 22.767, 14.4816, 23.8039, 15.4713)
    ..lineTo(26.6653, 12.6057)
    ..cubicTo(24.936, 10.9908, 22.6786, 10, 19.9849, 10)
    ..cubicTo(16.0832, 10, 12.705, 12.2414, 11.0618, 15.5076)
    ..cubicTo(10.383, 16.8592, 10, 18.3834, 10, 19.9994)
    ..cubicTo(10, 21.6155, 10.383, 23.1396, 11.0618, 24.4913)
    ..cubicTo(12.705, 27.7597, 16.0832, 30, 19.9849, 30)
    ..cubicTo(22.6797, 30, 24.9485, 29.1137, 26.6018, 27.5861)
    ..cubicTo(28.4887, 25.8452, 29.5732, 23.2702, 29.5732, 20.2275)
    ..cubicTo(29.5732, 19.5182, 29.5131, 18.835, 29.3987, 18.1825)
    ..lineTo(29.3987, 18.1814)
    ..close();

  /// The kit's conic gradient: CSS `conic-gradient(from 90deg, …)` turned
  /// 45° anticlockwise, so it starts at the G's upper right.
  static const _sweep = SweepGradient(
    transform: GradientRotation(-math.pi / 4),
    colors: [
      Color(0xFFFF4641),
      Color(0xFFFF4641),
      Color(0xFF3186FF),
      Color(0xFF3186FF),
      Color(0xFF00A5B7),
      Color(0xFF0EBC5F),
      Color(0xFF0EBC5F),
      Color(0xFF6CC400),
      Color(0xFFFFCC00),
      Color(0xFFFFD314),
      Color(0xFFFFCC00),
      Color(0xFFFF6A2B),
      Color(0xFFFD4641),
      Color(0xFFFF4641),
      Color(0xFFFF4641),
    ],
    stops: [
      0,
      4.14555 / 360,
      39.154 / 360,
      72.0044 / 360,
      96.7463 / 360,
      120.897 / 360,
      154.722 / 360,
      179.136 / 360,
      203.588 / 360,
      226.915 / 360,
      251.688 / 360,
      273.129 / 360,
      289.305 / 360,
      359.593 / 360,
      1,
    ],
  );

  /// The kit's highlights: centre, radii, rotation in degrees and colour,
  /// each blurred by a standard deviation of 1.
  static const _highlights = [
    (Offset(20.0496, 20.2413), Size(5.39634, 2.83537), 24.4473, 0xFF3186FF),
    (Offset(33.3538, 18.2155), Size(7.43918, 3.09357), 0.0, 0xFF3186FF),
    (Offset(25.2744, 16.2195), Size(7.40854, 2.37805), 0.0, 0xFFFF4641),
    (Offset(29.5427, 12.9268), Size(7.40854, 2.37805), 0.0, 0xFFFF5B8B),
    (Offset(24.4817, 19.878), Size(8.5061, 3.10976), 0.0, 0xFF3186FF),
    (Offset(25.1842, 14.0197), Size(4.53882, 2.37805), -28.6599, 0xFFFF4641),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(size.width / 20)
      ..translate(-10, -10)
      ..clipPath(_g)
      // The kit also blurs the sweep slightly, which only softens colour
      // changes that are already gradual; left out.
      ..drawOval(
        const Rect.fromLTRB(7.25922, 6.90668, 32.9973, 32.6786),
        Paint()
          ..shader = _sweep.createShader(
            Rect.fromCircle(center: const Offset(19.6819, 19.7927), radius: 1),
          ),
      );
    final blur = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    for (final (centre, radii, degrees, color) in _highlights) {
      canvas
        ..save()
        ..translate(centre.dx, centre.dy)
        ..rotate(degrees * math.pi / 180)
        ..drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: radii.width * 2,
            height: radii.height * 2,
          ),
          blur..color = Color(color),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter old) => false;
}
