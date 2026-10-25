import 'package:app_ui/app_ui.dart';
import 'package:compound/challenges/logic/challenge_standings.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound_charts/compound_charts.dart';

/// "Challenges" under Social's leaderboard (`ChallengesDashboardSection`):
/// one summary card per running challenge, with days left, the reader's
/// ring and the top three, and New.
class ChallengesSection extends StatelessWidget {
  const new({
    required this.cards,
    required this.viewerId,
    required this.onCardPressed,
    required this.onCreatePressed,
    super.key,
  });

  final List<ChallengeCard> cards;
  final String viewerId;
  final ValueChanged<ChallengeCard> onCardPressed;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppSection(
      header: l10n.challengesTitle,
      trailing: Semantics(
        label: l10n.challengesNewLabel,
        excludeSemantics: true,
        button: true,
        child: AppChip(label: l10n.challengesNew, onPressed: onCreatePressed),
      ),
      grouped: false,
      children: [
        if (cards.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: Text(
              l10n.challengesEmpty,
              style: AppTextStyles.rowDetail.secondary(context),
            ),
          ),
        for (final card in cards)
          _Card(
            card: card,
            viewerId: viewerId,
            onPressed: () => onCardPressed(card),
          ),
      ],
    );
  }
}

/// A running challenge as a summary card: the reader's sessions out of the
/// target beside their ring, the days left, and the top three.
class _Card extends StatelessWidget {
  const new({
    required this.card,
    required this.viewerId,
    required this.onPressed,
  });

  final ChallengeCard card;
  final String viewerId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final target = card.challenge.targetSessions;
    final done = card.mySessions >= target;
    return AppSummaryCard(
      title: card.challenge.title,
      icon: AppSymbols.challenge,
      tint: colors.workouts,
      value:
          '${AppFormat.number(card.mySessions)}/'
          '${AppFormat.number(target)}',
      unit: l10n.challengeSessionsUnit(target),
      // Reaching the target is the reader's own progress: the accent.
      delta: done
          ? AppChip(
              label: l10n.streakGoalMet,
              icon: AppSymbols.success,
              selected: true,
            )
          : AppChip(label: l10n.challengeDaysLeft(card.daysLeft)),
      chart: MediaQuery.withNoTextScaling(
        child: ProgressArc(
          value: ChallengeStandings.ringProgress(
            sessions: card.mySessions,
            target: target,
          ),
          color: colors.accentInk,
          diameter: AppControlSize.cta,
          strokeWidth: AppChartMark.arcWidthSmall,
        ),
      ),
      chartBeside: true,
      footer: [
        for (final (index, entry) in card.topThree.indexed)
          l10n.challengeTopEntry(
            index + 1,
            entry.userId == viewerId
                ? l10n.socialYou
                : entry.name ?? l10n.challengeMember,
            entry.sessions,
          ),
      ].join(' · '),
      onTap: onPressed,
    );
  }
}
