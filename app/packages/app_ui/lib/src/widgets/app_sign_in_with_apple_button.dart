import 'package:app_ui/app_ui.dart';

/// {@template app_sign_in_with_apple_button}
/// Apple's "Continue with Apple" button, drawn as Apple's Human Interface
/// Guidelines set out for a custom Sign in with Apple button, so it is the
/// same on iOS and Android (Swift's `SignInWithAppleButtonView`, which
/// wraps the system button):
///
/// - black with a white logo and title in light mode, white with black in
///   dark mode;
/// - the Apple logo from Apple's own "Sign in with Apple" logo artwork
///   (left-aligned, medium), as tall as the button;
/// - the title 43% of the button's height, as the system button's is;
/// - 56 points tall with capsule ends, as the Swift app's.
///
/// While [isLoading] a spinner takes the logo and title's place.
/// {@endtemplate}
class AppSignInWithAppleButton extends StatelessWidget {
  /// {@macro app_sign_in_with_apple_button}
  const new({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  /// "Continue with Apple", localized. Apple allows only that, "Sign in
  /// with Apple" and "Sign up with Apple".
  final String label;

  /// Called when tapped. `null` disables the button.
  final VoidCallback? onPressed;

  /// Whether sign-in is under way.
  final bool isLoading;

  /// The Swift app's height.
  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? Colors.white : Colors.black;
    final foreground = dark ? Colors.black : Colors.white;
    final onTap = isLoading ? null : onPressed;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: foreground.withValues(alpha: 0.2),
          highlightColor: foreground.withValues(alpha: 0.1),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: isLoading
                ? Center(
                    child: SizedBox.square(
                      dimension: AppIconSize.small.of(context),
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(foreground),
                      ),
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          size: const Size(
                            height * _AppleLogoPainter.width / 44,
                            height,
                          ),
                          painter: _AppleLogoPainter(foreground),
                        ),
                        Text(
                          label,
                          // Like the system button, the title keeps its
                          // proportion to the button rather than scaling
                          // with the text size setting.
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            color: foreground,
                            fontSize: height * 0.43,
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        ),
                        // Balances the logo file's leading padding.
                        const SizedBox(width: AppSpacing.m),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Apple's logo file "Logo - SIWA - Left-aligned - Medium" (Apple Design
/// Resources, Sign in with Apple), its 31 × 44 box and padding kept as
/// Apple asks: never cropped, matched to the button's height.
class _AppleLogoPainter extends CustomPainter {
  new(this.color);

  final Color color;

  /// The logo file's width, out of a height of 44.
  static const double width = 31;

  static final _logo = Path()
    ..moveTo(15.71, 14.885)
    ..cubicTo(16.568, 14.885, 17.643, 14.305, 18.283, 13.532)
    ..cubicTo(18.863, 12.831, 19.285, 11.853, 19.285, 10.874)
    ..cubicTo(19.285, 10.742, 19.273, 10.609, 19.249, 10.5)
    ..cubicTo(18.295, 10.536, 17.147, 11.14, 16.459, 11.949)
    ..cubicTo(15.915, 12.565, 15.42, 13.532, 15.42, 14.522)
    ..cubicTo(15.42, 14.667, 15.444, 14.812, 15.456, 14.86)
    ..cubicTo(15.517, 14.873, 15.613, 14.885, 15.71, 14.885)
    ..close()
    ..moveTo(12.69, 29.5)
    ..cubicTo(13.862, 29.5, 14.381, 28.715, 15.843, 28.715)
    ..cubicTo(17.329, 28.715, 17.655, 29.476, 18.959, 29.476)
    ..cubicTo(20.24, 29.476, 21.097, 28.292, 21.906, 27.133)
    ..cubicTo(22.812, 25.804, 23.187, 24.499, 23.211, 24.439)
    ..cubicTo(23.126, 24.415, 20.674, 23.412, 20.674, 20.598)
    ..cubicTo(20.674, 18.158, 22.607, 17.059, 22.716, 16.974)
    ..cubicTo(21.435, 15.138, 19.491, 15.09, 18.959, 15.09)
    ..cubicTo(17.522, 15.09, 16.35, 15.96, 15.613, 15.96)
    ..cubicTo(14.816, 15.96, 13.765, 15.138, 12.521, 15.138)
    ..cubicTo(10.154, 15.138, 7.75, 17.095, 7.75, 20.791)
    ..cubicTo(7.75, 23.086, 8.644, 25.514, 9.743, 27.084)
    ..cubicTo(10.685, 28.413, 11.507, 29.5, 12.69, 29.5)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / 44;
    canvas
      ..scale(scale)
      ..drawPath(_logo, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AppleLogoPainter old) => old.color != color;
}
