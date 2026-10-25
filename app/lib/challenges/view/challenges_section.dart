import 'package:app_ui/app_ui.dart';
import 'package:compound/challenges/logic/challenge_standings.dart';
import 'package:compound/challenges/view/challenge_ring.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/view/people_widgets.dart' show UserAvatar;

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.m,
      ),
      child: AppSection(
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
      ),
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
                          style: AppTextStyles.sectionTitle,
                        ),
                        Text(
                          l10n.challengeDaysLeft(card.daysLeft),
                          style: AppTextStyles.rowDetail.secondary(context),
                        ),
                        for (final (index, entry) in card.topThree.indexed)
                          Row(
                            spacing: AppSpacing.xs,
                            children: [
                              UserAvatar(
                                imageUrl: entry.imageUrl,
                                size: AppIconSize.small.of(context),
                              ),
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
