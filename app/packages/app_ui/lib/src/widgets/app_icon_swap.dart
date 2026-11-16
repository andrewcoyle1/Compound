import 'package:app_ui/app_ui.dart';

/// {@template app_icon_swap}
/// Swaps one icon for another when [value] changes (a circle for a tick, an
/// outline for a fill), so the change reads as the state changing rather
/// than a glitch.
///
/// The new icon grows from 0.3 as it fades in over [AppMotion.quick], while
/// the old one shrinks and fades out on the exit timing, at the same time
/// and in the same spot, so nothing around them moves. With reduced motion
/// (`MediaQuery.disableAnimations`) the new icon simply replaces the old.
///
/// For icons that change with state only: never navigation icons or text.
/// {@endtemplate}
class AppIconSwap extends StatelessWidget {
  /// {@macro app_icon_swap}
  const new({required this.value, required this.child, super.key});

  /// How small an icon starts and ends: a deep scale reads as a swap, a
  /// shallow one as a glitch.
  static const double hiddenScale = 0.3;

  /// The state [child] shows; a new value swaps it in.
  final Object? value;

  /// The icon for [value].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyed = KeyedSubtree(key: ValueKey(value), child: child);
    if (MediaQuery.disableAnimationsOf(context)) return keyed;
    return AnimatedSwitcher(
      duration: AppMotion.quick.durationOf(context),
      reverseDuration: AppMotion.quick.exitDurationOf(context),
      switchInCurve: AppMotion.quick.curve,
      switchOutCurve: AppMotion.exitCurve,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: hiddenScale, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: keyed,
    );
  }
}
