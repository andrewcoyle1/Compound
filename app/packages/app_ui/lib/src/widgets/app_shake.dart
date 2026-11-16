import 'package:app_ui/app_ui.dart';

/// {@template app_shake}
/// Shakes [child] side to side each time [trigger] changes: the field that
/// was wrong when a submit failed (a taken username, a refused code).
///
/// Only for a failed submit, never as someone types or leaves a field, and
/// always with the message beside the field and the `error` haptic, which
/// the caller plays. Nothing moves with reduced motion
/// (`MediaQuery.disableAnimations`); the message and the haptic still say
/// it.
/// {@endtemplate}
class AppShake extends StatefulWidget {
  /// {@macro app_shake}
  const new({required this.trigger, required this.child, super.key});

  /// How long one shake lasts.
  static const duration = Duration(milliseconds: 360);

  /// The offsets the shake passes through, in logical pixels.
  static const offsets = <double>[0, -10, 10, -6, 6, -3, 0];

  /// Changes to start a shake, such as a count of failures.
  final Object? trigger;

  /// What shakes.
  final Widget child;

  @override
  State<AppShake> createState() => _AppShakeState();
}

class _AppShakeState extends State<AppShake>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppShake.duration,
  );
  late final Animation<double> _offset = TweenSequence([
    for (var i = 1; i < AppShake.offsets.length; i++)
      TweenSequenceItem(
        tween: Tween(
          begin: AppShake.offsets[i - 1],
          end: AppShake.offsets[i],
        ).chain(CurveTween(curve: AppMotion.standard.curve)),
        weight: 1,
      ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(AppShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _offset,
    builder: (context, child) =>
        Transform.translate(offset: Offset(_offset.value, 0), child: child),
    child: widget.child,
  );
}
