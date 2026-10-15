import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/training_analytics/view/training_analytics_widgets.dart';
import 'package:compound_maths/compound_maths.dart';
import 'package:intl/intl.dart' show NumberFormat;

/// A muscle's suggestion for its next two to three weeks of sets, with the
/// figures it rests on (Swift `VolumeRecommendationSection`). A suggestion
/// only: nothing in the user's templates changes.
class VolumeRecommendationSection extends StatelessWidget {
  const new({required this.suggestion, super.key});

  /// The suggestion.
  final VolumeSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final suggested = suggestion.suggestedSets;
    final trend = suggestion.trendPercentPerWeek;
    final adherence = suggestion.adherence;
    final (headline, detail, icon, tint) = switch (suggestion.action) {
      VolumeAction.keep => (
        l10n.volumeKeepTitle,
        l10n.volumeKeepDetail,
        AppSymbols.success,
        colors.success,
      ),
      VolumeAction.add => (
        l10n.volumeAddTitle,
        l10n.volumeAddDetail,
        AppSymbols.increase,
        null,
      ),
      VolumeAction.reduce => (
        l10n.volumeReduceTitle,
        l10n.volumeReduceDetail,
        AppSymbols.reduce,
        colors.warning,
      ),
      VolumeAction.beConsistent => (
        l10n.volumeConsistencyTitle,
        l10n.volumeConsistencyDetail,
        AppSymbols.calendar,
        null,
      ),
      VolumeAction.needsMoreData => (
        l10n.volumeMoreDataTitle,
        l10n.volumeMoreDataDetail,
        AppSymbols.info,
        null,
      ),
    };
    String sets(double value) => setsText(l10n, value, locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s,
      children: [
        AnalyticsSectionHeader(
          title: l10n.volumeRecommendationTitle,
          info: MethodInfo.volumeRecommendation(l10n),
        ),
        AppSection(
          footer: suggestion.isHighVolume ? l10n.volumeHighFooter : null,
          children: [
            AppListRow(
              title: headline,
              subtitle: detail,
              icon: icon,
              tint: tint ?? Theme.of(context).colorScheme.primary,
            ),
            AppListRow(
              title: l10n.volumeRecentWeeks,
              accessory: AppListRowValue(sets(suggestion.baselineSets)),
            ),
            if (suggested != null)
              AppListRow(
                title: l10n.volumeSuggested,
                accessory: AppListRowValue(
                  suggested.low == suggested.high
                      ? sets(suggested.low)
                      : l10n.setCountDecimal(
                          AppFormat.repRange(
                            suggested.low.round(),
                            suggested.high.round(),
                            locale: locale,
                          ),
                        ),
                ),
              ),
            if (trend != null)
              AppListRow(
                title: l10n.volumeStrengthTrend,
                accessory: AppListRowValue(
                  l10n.perWeek(_signedPercent(trend, locale)),
                ),
              ),
            if (adherence != null)
              AppListRow(
                title: l10n.volumePlannedSetsDone,
                accessory: AppListRowValue(
                  AppFormat.percent(adherence, locale: locale),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// "+1.2%", "−0.4%": one decimal, the sign always shown.
String _signedPercent(double percent, String locale) {
  final format = NumberFormat.decimalPercentPattern(
    locale: locale,
    decimalDigits: 1,
  );
  return '${percent < 0 ? '−' : '+'}${format.format(percent.abs() / 100)}';
}
