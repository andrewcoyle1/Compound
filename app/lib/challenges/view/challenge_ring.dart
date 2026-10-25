import 'package:app_ui/app_ui.dart';
import 'package:compound/challenges/logic/challenge_standings.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound_charts/compound_charts.dart';

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
    final large = size >= 80;
    final progress = ChallengeStandings.ringProgress(
      sessions: sessions,
      target: target,
    );
    final ink = context.appColors.accentInk;
    return ProgressArc(
      value: progress,
      diameter: size,
      strokeWidth: large ? AppChartMark.arcWidth : AppChartMark.arcWidthSmall,
      // Done is the accent, not success green: a closed ring stays in it.
      color: ink,
      trackColor: AppColors.tintedSurface(
        Theme.of(context).colorScheme.primary,
      ),
      semanticLabel: context.l10n.challengeRingLabel(sessions, target),
      child: Text(
        '$sessions/$target',
        maxLines: 1,
        style: large ? AppTextStyles.metric : AppTextStyles.metricSmall,
      ),
    );
  }
}
