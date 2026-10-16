import 'package:app_ui/app_ui.dart';
import 'package:compound/challenges/logic/challenge_standings.dart';
import 'package:compound/challenges/view/challenge_ring.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/view/people_widgets.dart';

/// "Challenges" under Social's leaderboard (`ChallengesDashboardSection`):
/// one card per running challenge, with days left, the reader's ring and
/// the top three, and New.
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
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialSectionHeader(
          title: l10n.challengesTitle,
          action: Semantics(
            label: l10n.challengesNewLabel,
            excludeSemantics: true,
            button: true,
            child: TextButton(
              onPressed: onCreatePressed,
              child: Text(l10n.challengesNew),
            ),
          ),
        ),
        if (cards.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.m,
            ),
            child: Text(
              l10n.challengesEmpty,
              style: AppTextStyles.rowDetail.copyWith(color: secondary),
            ),
          ),
        for (final card in cards)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.m,
            ),
            child: _Card(
              card: card,
              viewerId: viewerId,
              onPressed: () => onCardPressed(card),
            ),
          ),
      ],
    );
  }
}

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
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      hint: l10n.challengeOpensStandings,
      child: MergeSemantics(
        child: AppCard(
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Row(
                spacing: AppSpacing.l,
                children: [
                  ChallengeRing(
                    sessions: card.mySessions,
                    target: card.challenge.targetSessions,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: AppSpacing.xs,
                      children: [
                        Text(
                          card.challenge.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.rowTitle.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          l10n.challengeDaysLeft(card.daysLeft),
                          style: AppTextStyles.rowDetail.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        for (final (index, entry) in card.topThree.indexed)
                          Row(
                            spacing: AppSpacing.xs,
                            children: [
                              UserAvatar(imageUrl: entry.imageUrl, size: 20),
                              Flexible(
                                child: Text(
                                  l10n.challengeTopEntry(
                                    index + 1,
                                    entry.userId == viewerId
                                        ? l10n.socialYou
                                        : entry.name ?? l10n.challengeMember,
                                    entry.sessions,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.label,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    AppSymbols.disclosure,
                    color: scheme.outline,
                    size: AppIconSize.small.of(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
