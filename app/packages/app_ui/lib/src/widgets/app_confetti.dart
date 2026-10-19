import 'package:app_ui/app_ui.dart';
import 'package:confetti/confetti.dart';

/// {@template app_confetti}
/// A burst of confetti from the middle of [child], for a moment worth
/// celebrating: a Today task done, a workout finished.
///
/// It bursts when [play] turns true, and once when it first appears if
/// [playsOnMount] is set. The pieces are the accent and the metric
/// colours, fly above everything on the screen without taking a tap, and
/// are cleared after [lifetime]. It never plays when the user has asked for
/// reduced motion, nor without an [Overlay] to draw in.
/// {@endtemplate}
class AppConfetti extends StatefulWidget {
  /// {@macro app_confetti}
  const new({
    required this.child,
    this.play = false,
    this.playsOnMount = false,
    super.key,
  });

  /// What the confetti bursts from.
  final Widget child;

  /// Bursts each time this turns true.
  final bool play;

  /// Bursts once when first built.
  final bool playsOnMount;

  /// How long a burst stays on screen: it is thrown for
  /// [AppMotion.emphasis], falls, and fades out at the end.
  static final Duration lifetime = AppMotion.emphasis.duration * 8;

  @override
  State<AppConfetti> createState() => _AppConfettiState();
}

class _AppConfettiState extends State<AppConfetti>
    with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _confetti = ConfettiController(duration: AppMotion.emphasis.duration);
  late final _life =
      AnimationController(vsync: this, duration: AppConfetti.lifetime)
        ..addStatusListener((status) {
          if (status.isCompleted) _portal.hide();
        });

  @override
  void initState() {
    super.initState();
    if (widget.playsOnMount) _burstAfterFrame();
  }

  @override
  void didUpdateWidget(AppConfetti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) _burstAfterFrame();
  }

  /// Bursts once the child is laid out, so the pieces start from where it is.
  void _burstAfterFrame() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _burst());

  void _burst() {
    if (!mounted ||
        Overlay.maybeOf(context) == null ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      return;
    }
    _confetti.play();
    _portal.show();
    _life.forward(from: 0);
  }

  @override
  void dispose() {
    _life.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final colors = context.appColors;
        return IgnorePointer(
          child: FadeTransition(
            opacity: ReverseAnimation(
              CurvedAnimation(
                parent: _life,
                curve: const Interval(0.75, 1, curve: Curves.easeIn),
              ),
            ),
            child: CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.center,
              showWhenUnlinked: false,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 24,
                emissionFrequency: 0.04,
                minBlastForce: 8,
                maxBlastForce: 30,
                gravity: 0.25,
                minimumSize: const Size(8, 4),
                maximumSize: const Size(14, 7),
                pauseEmissionOnLowFrameRate: false,
                colors: [
                  scheme.primary,
                  colors.workouts,
                  colors.steps,
                  colors.nutrition,
                  colors.scaleWeight,
                  colors.habits,
                  colors.personalRecord,
                ],
              ),
            ),
          ),
        );
      },
      child: widget.child,
    ),
  );
}
