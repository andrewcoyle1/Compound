import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:compound/challenges/logic/challenge_standings.dart';
import 'package:compound/l10n/l10n.dart';

/// A progress ring with the count inside (`ChallengeRing`): Social's card
/// and the detail header. It grows with the text size.
class ChallengeRing extends StatelessWidget {
  const new({
    required this.sessions,
    required this.target,
    this.size = 56,
    super.key,
  });

  final int sessions;
  final int target;
  final double size;

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.textScalerOf(context).scale(size);
    final progress = ChallengeStandings.ringProgress(
      sessions: sessions,
      target: target,
    );
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: context.l10n.challengeRingLabel(sessions, target),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: side,
        child: CustomPaint(
          painter: _RingPainter(
            progress: progress,
            track: AppColors.tintedSurface(scheme.primary),
            fill: progress >= 1 ? context.appColors.success : scheme.primary,
            width: side / 9,
          ),
          child: Padding(
            padding: EdgeInsets.all(side / 8),
            child: Center(
              child: FittedBox(
                child: Text(
                  '$sessions/$target',
                  maxLines: 1,
                  style: size >= 80
                      ? AppTextStyles.metric
                      : AppTextStyles.metricSmall,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const new({
    required this.progress,
    required this.track,
    required this.fill,
    required this.width,
  });

  final double progress;
  final Color track;
  final Color fill;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      paint
        ..color = fill
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.fill != fill ||
      old.width != width;
}
