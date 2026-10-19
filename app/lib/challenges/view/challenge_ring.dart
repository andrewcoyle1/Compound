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
    final scaler = MediaQuery.textScalerOf(context);
    final large = size >= 80;
    final progress = ChallengeStandings.ringProgress(
      sessions: sessions,
      target: target,
    );
    final scheme = Theme.of(context).colorScheme;
    return ProgressArc(
      value: progress,
      diameter: scaler.scale(size),
      strokeWidth: scaler.scale(
        large ? AppChartMark.arcWidth : AppChartMark.arcWidthSmall,
      ),
      color: progress >= 1 ? context.appColors.success : scheme.primary,
      trackColor: AppColors.tintedSurface(scheme.primary),
      semanticLabel: context.l10n.challengeRingLabel(sessions, target),
      child: Text(
        '$sessions/$target',
        maxLines: 1,
        style: large ? AppTextStyles.metric : AppTextStyles.metricSmall,
      ),
    );
  }
}
