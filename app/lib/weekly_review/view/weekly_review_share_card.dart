import 'package:compound/l10n/l10n.dart';
import 'package:compound/sharing/share_card/workout_share_card.dart';
import 'package:flutter/material.dart';

/// The Weekly Review as a Stories-sized image, drawn like the workout card
/// (`WeeklyReviewShareCardView`). Privacy: numbers only, no name, no body
/// weight, no nutrition.
class WeeklyReviewShareCard extends StatelessWidget {
  const new({
    required this.l10n,
    required this.accent,
    required this.dateRange,
    required this.takeaway,
    required this.sessions,
    required this.volume,
    required this.records,
    super.key,
  });

  /// Stories-sized, as the workout card's story.
  static final Size size = ShareCardFormat.story.size;

  final AppLocalizations l10n;
  final Color accent;
  final String dateRange;
  final String takeaway;
  final String sessions;
  final String volume;

  /// Each record as "Bench 100 kg × 5"; the first three are drawn.
  final List<String> records;

  @override
  Widget build(BuildContext context) {
    return ShareCardFrame(
      accent: accent,
      size: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text(
                l10n.weeklyReviewTitle,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              Text(
                dateRange,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          Text(
            takeaway,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              ShareCardStat(header: l10n.weeklyReviewSessions, value: sessions),
              ShareCardStat(header: l10n.statVolume, value: volume),
              ShareCardStat(
                header: l10n.weeklyReviewCardPrs,
                value: '${records.length}',
              ),
            ],
          ),
          if (records.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                for (final record in records.take(3))
                  Row(
                    spacing: 6,
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      Flexible(
                        child: Text(
                          record,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
