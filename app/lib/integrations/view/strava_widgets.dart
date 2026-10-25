import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/integrations/cubit/strava_cubit.dart';
import 'package:compound/integrations/link_opener.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/social/view/people_widgets.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:strava_repository/strava_repository.dart';

// Imported Strava activities. Strava's terms keep an athlete's data to the
// athlete, so these widgets go on the owner's own screens only (the weekly
// review and their own profile), never anywhere followers see.

/// The week's imported activities added up (Swift `WeeklyReviewView`'s
/// "From Strava"), or nothing when there were none.
class StravaWeekSection extends StatelessWidget {
  const new({required this.weekStart, required this.distanceUnit, super.key});

  /// The week's first day, local midnight.
  final DateTime weekStart;

  /// The profile's distance preference.
  final DistanceUnitPreference? distanceUnit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final activities = context
        .select<StravaCubit, List<StravaImportedActivity>>(
          (cubit) => cubit.state.activities,
        );
    final totals = StravaTotals.of(
      activities,
      start: weekStart,
      end: DateTime(weekStart.year, weekStart.month, weekStart.day + 7),
    );
    if (totals == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: AppSection(
        header: l10n.stravaFromStrava,
        children: [
          AppListRow(
            title: l10n.stravaActivities,
            accessory: AppListRowValue(
              AppFormat.number(totals.count, locale: locale),
            ),
          ),
          if (totals.distanceMeters > 0)
            AppListRow(
              title: l10n.stravaDistance,
              accessory: AppListRowValue(
                AppFormat.distance(
                  totals.distanceMeters,
                  WorkoutText.preferredDistanceUnit(distanceUnit),
                  locale: locale,
                ),
              ),
            ),
          AppListRow(
            title: l10n.stravaMovingTime,
            accessory: AppListRowValue(
              AppFormat.duration(Duration(seconds: totals.movingTime)),
            ),
          ),
        ],
      ),
    );
  }
}

/// This calendar year's imported activities and the latest three (Swift
/// `SocialProfileView.stravaSection`), or nothing when there were none.
/// Place it on the reader's own profile only.
class StravaYearSection extends StatelessWidget {
  const new({required this.distanceUnit, this.now, super.key});

  /// The profile's distance preference.
  final DistanceUnitPreference? distanceUnit;

  /// Today, for the year; the clock when null.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final activities = context
        .select<StravaCubit, List<StravaImportedActivity>>(
          (cubit) => cubit.state.activities,
        );
    final year = (now ?? DateTime.now()).year;
    final totals = StravaTotals.of(
      activities,
      start: DateTime(year),
      end: DateTime(year + 1),
    );
    if (totals == null) return const SizedBox.shrink();
    final unit = WorkoutText.preferredDistanceUnit(distanceUnit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialSectionHeader(title: l10n.stravaThisYear),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.m,
              children: [
                Wrap(
                  spacing: AppSpacing.xxl,
                  runSpacing: AppSpacing.s,
                  children: [
                    AppStat(
                      value: AppFormat.number(totals.count, locale: locale),
                      label: l10n.stravaActivities,
                      size: AppStatSize.small,
                    ),
                    AppStat(
                      value: AppFormat.distance(
                        totals.distanceMeters,
                        unit,
                        locale: locale,
                      ),
                      label: l10n.stravaDistance,
                      size: AppStatSize.small,
                    ),
                    AppStat(
                      value: AppFormat.duration(
                        Duration(seconds: totals.movingTime),
                      ),
                      label: l10n.socialTime,
                      size: AppStatSize.small,
                    ),
                  ],
                ),
                // `activities` is newest first.
                for (final activity in activities.take(3))
                  StravaActivityRow(activity: activity, distanceUnit: unit),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One imported activity, linking to it with the wording Strava's brand
/// guidelines ask for.
class StravaActivityRow extends StatelessWidget {
  const new({required this.activity, required this.distanceUnit, super.key});

  final StravaImportedActivity activity;
  final AppDistanceUnit distanceUnit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final detail = [
      AppFormat.date(activity.startDate.toLocal(), locale: context.dateLocale),
      if (activity.distance > 0)
        AppFormat.distance(activity.distance, distanceUnit, locale: locale),
      AppFormat.duration(Duration(seconds: activity.movingTime)),
    ].join(' · ');
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () =>
            unawaited(context.read<LinkOpener>().open(activity.stravaUri)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppControlSize.row),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xxs,
            children: [
              Text(activity.name, style: AppTextStyles.rowTitle),
              Text(
                detail,
                style: AppTextStyles.rowDetail.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                l10n.stravaViewOn,
                style: AppTextStyles.label.copyWith(
                  color: context.appColors.accentInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
