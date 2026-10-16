import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart' show localDayKey;
import 'package:compound/app/app.dart';
import 'package:compound/coach/coach.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:compound/l10n/first_weekday.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:compound/sharing/share_card/share_card_content.dart';
import 'package:compound/sharing/share_card/share_card_renderer.dart';
import 'package:compound/sharing/share_sheet.dart';
import 'package:compound/training_analytics/view/training_analytics_widgets.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/weekly_review/bloc/weekly_review_bloc.dart';
import 'package:compound/weekly_review/logic/weekly_review.dart';
import 'package:compound/weekly_review/view/weekly_review_share_card.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// The user's own week (Swift `WeeklyReviewView`): sessions against goal,
/// volume against last week, sets per muscle, records, RPE, the weight
/// trend and calorie adherence, with a one-line takeaway on top. Pushed
/// from Today.
class WeeklyReviewPage extends StatelessWidget {
  const new({super.key});

  /// The path under the Today tab.
  static const path = 'weekly-review';

  /// The route name.
  static const name = 'weeklyReview';

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    final analytics = context.read<AnalyticsRepository>();
    final firstDay = firstDayOfWeekIndex(context);
    return BlocProvider(
      create: (context) => WeeklyReviewBloc(
        workoutSessionRepository: context.read<WorkoutSessionRepository>(),
        nutritionRepository: context.read<NutritionRepository>(),
        bodyRepository: context.read<BodyRepository>(),
        trainingLibraryRepository: context.read<TrainingLibraryRepository>(),
        userRepository: context.read<UserRepository>(),
        analyticsRepository: analytics,
        uid: state.user.uid,
        firstDayOfWeek: firstDay,
      )..add(const WeeklyReviewSubscriptionRequested()),
      child: OnDispose(
        onDispose: () => analytics.disappear(WeeklyReviewBloc.screen),
        child: const WeeklyReviewView(),
      ),
    );
  }
}

class WeeklyReviewView extends StatelessWidget {
  const new({super.key});

  /// The takeaway's sentence (Swift `WeeklyReview.takeaway`).
  static String takeawayText(
    AppLocalizations l10n,
    WeeklyTakeaway takeaway,
    String locale,
  ) => switch (takeaway) {
    NoSessionsTakeaway() => l10n.weeklyReviewNoSessions,
    GoalAndRecordsTakeaway(:final records) => l10n.weeklyReviewGoalAndRecords(
      records,
    ),
    GoalHitTakeaway(:final sessions, :final goal) => l10n.weeklyReviewGoalHit(
      sessions,
      goal,
    ),
    VolumeUpTakeaway(:final change) => l10n.weeklyReviewVolumeUp(
      '${AppFormat.number((change * 100).round(), locale: locale)}%',
    ),
    SessionsToGoTakeaway(:final sessions) => l10n.weeklyReviewSessionsToGo(
      sessions,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<WeeklyReviewBloc>().state;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.weeklyReviewTitle),
        actions: [
          if (state.status == WeeklyReviewStatus.loaded)
            _ShareButton(state: state),
          AskCoachButton(
            CoachContext(
              kind: CoachContextKind.weeklyReview,
              date: localDayKey(state.weekStart),
              title: l10n.weeklyReviewTitle,
            ),
          ),
        ],
      ),
      body: switch (state.status) {
        WeeklyReviewStatus.loading => const Center(
          child: CircularProgressIndicator.adaptive(),
        ),
        WeeklyReviewStatus.failure => AnalyticsMessage(
          title: l10n.weeklyReviewTitle,
          message: l10n.trainingAnalyticsLoadFailure,
        ),
        WeeklyReviewStatus.loaded => _Review(state: state),
      },
    );
  }
}

class _Review extends StatelessWidget {
  const new({required this.state});

  final WeeklyReviewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final review = state.review(l10n.muscleName);
    final volumeUnit = WorkoutText.weightUnit(review.volumeUnit);
    final bodyUnit = state.usesPounds
        ? AppWeightUnit.pounds
        : AppWeightUnit.kilograms;
    String number(num v, [int decimals = 0]) =>
        AppFormat.number(v, maxFractionDigits: decimals, locale: locale);
    String percent(double fraction) => '${number((fraction * 100).round())}%';
    final change = review.volumeChange;
    final latest = review.latestWeightKg;
    final weightChange = review.weightChangeKg;
    String weight(double kg) => AppFormat.weight(kg, bodyUnit, locale: locale);
    final weightText = latest == null
        ? null
        : weightChange == null
        ? weight(latest)
        : '${weight(latest)} '
              '(${weightChange > 0
                  ? '+'
                  : weightChange < 0
                  ? '−'
                  : '±'}${weight(weightChange.abs())})';
    final nutrition = review.nutrition;
    final rpe = review.averageRpe;
    const gap = SizedBox(height: AppSpacing.xl);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        _WeekHeader(state: state, review: review),
        const SizedBox(height: AppSpacing.s),
        AppSection(
          children: [
            AppListRow(
              title: WeeklyReviewView.takeawayText(
                l10n,
                review.takeaway,
                locale,
              ),
              accessory: AppListRowCustom(
                MethodInfoButton(MethodInfo.weeklySessionGoal(l10n)),
              ),
            ),
          ],
        ),
        gap,
        AppSection(
          header: l10n.tabTraining,
          children: [
            AppListRow(
              title: l10n.weeklyReviewSessions,
              accessory: AppListRowValue(
                l10n.weeklyReviewOfGoal(review.sessionCount, review.goal),
              ),
            ),
            AppListRow(
              title: l10n.statVolume,
              subtitle: change == null
                  ? null
                  : l10n.weeklyReviewVolumeChange(
                      '${change >= 0 ? '+' : ''}${percent(change)}',
                    ),
              accessory: AppListRowValue(
                AppFormat.weight(review.volumeKg, volumeUnit, locale: locale),
              ),
            ),
            if (rpe != null)
              AppListRow(
                title: l10n.weeklyReviewAverageRpe,
                accessory: AppListRowValue(number(rpe, 1)),
              ),
          ],
        ),
        if (review.setsPerMuscle.isNotEmpty) ...[
          gap,
          AnalyticsSectionHeader(
            title: l10n.weeklyReviewSetsPerMuscle,
            info: MethodInfo.weeklyHardSets(l10n),
          ),
          const SizedBox(height: AppSpacing.s),
          AppSection(
            children: [
              for (final entry in review.setsPerMuscle)
                AppListRow(
                  title: l10n.muscleName(entry.muscle),
                  accessory: AppListRowValue(number(entry.sets, 1)),
                ),
            ],
          ),
        ],
        if (review.personalRecords.isNotEmpty) ...[
          gap,
          AppSection(
            header: l10n.weeklyReviewPersonalRecords,
            children: [
              for (final record in review.personalRecords)
                AppListRow(
                  title: record.exerciseName,
                  icon: AppSymbols.personalRecord,
                  tint: context.appColors.personalRecord,
                  accessory: AppListRowValue(
                    WorkoutText.recordDetail(l10n, record, locale: locale),
                  ),
                ),
            ],
          ),
        ],
        // The owner's own imported runs and rides (Strava's terms).
        StravaWeekSection(
          weekStart: state.weekStart,
          distanceUnit: state.user?.submittedDistanceUnitPreference,
        ),
        if (weightText != null || nutrition != null) ...[
          gap,
          if (nutrition != null) ...[
            AnalyticsSectionHeader(
              title: l10n.weeklyReviewBodyAndNutrition,
              info: MethodInfo.calorieAdherenceBand(l10n),
            ),
            const SizedBox(height: AppSpacing.s),
          ],
          AppSection(
            header: nutrition == null
                ? l10n.weeklyReviewBodyAndNutrition
                : null,
            children: [
              if (weightText != null)
                AppListRow(
                  title: l10n.weightTrendSeries,
                  accessory: AppListRowCustom(
                    // Bounded, so a long reading wraps instead of
                    // overflowing the row.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width / 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              weightText,
                              textAlign: TextAlign.end,
                              style: AppTextStyles.rowDetail.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                          MethodInfoButton(MethodInfo.weightTrend(l10n)),
                        ],
                      ),
                    ),
                  ),
                ),
              if (nutrition != null)
                // A subtitle, not a value: the sentence is too long to sit
                // beside the title in every language.
                AppListRow(
                  title: l10n.weeklyReviewCalories,
                  subtitle: l10n.weeklyReviewDaysOnTarget(
                    nutrition.daysOnTarget,
                    nutrition.daysLogged,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The week's dates between the previous and next week buttons.
class _WeekHeader extends StatelessWidget {
  const new({required this.state, required this.review});

  final WeeklyReviewState state;
  final WeeklyReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final days = DateFormat.MMMd(locale);
    final end = review.weekEnd;
    final last = DateTime(end.year, end.month, end.day - 1);
    final bloc = context.read<WeeklyReviewBloc>();
    return Row(
      children: [
        IconButton(
          icon: const Icon(AppSymbols.previous),
          tooltip: l10n.weeklyReviewPreviousWeek,
          onPressed: () => bloc.add(const WeeklyReviewPreviousWeekPressed()),
        ),
        Expanded(
          child: Text(
            '${days.format(review.weekStart)} – ${days.format(last)}',
            textAlign: TextAlign.center,
            style: AppTextStyles.rowDetail.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(AppSymbols.next),
          tooltip: l10n.weeklyReviewNextWeek,
          onPressed: state.canShowNextWeek
              ? () => bloc.add(const WeeklyReviewNextWeekPressed())
              : null,
        ),
      ],
    );
  }
}

/// Share: the week as a Stories image (`WeeklyReviewPresenter.onSharePressed`).
class _ShareButton extends StatefulWidget {
  const new({required this.state});

  final WeeklyReviewState state;

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _sharing = false;

  Future<void> _share() async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final review = widget.state.review(l10n.muscleName);
    final days = DateFormat.MMMd(locale);
    final end = review.weekEnd;
    final last = DateTime(end.year, end.month, end.day - 1);
    final shareSheet = context.read<ShareSheet>();
    final messenger = ScaffoldMessenger.of(context);
    context.read<WeeklyReviewBloc>().add(const WeeklyReviewSharePressed());
    setState(() => _sharing = true);
    final png = await renderShareCard(
      context,
      WeeklyReviewShareCard(
        l10n: l10n,
        accent: Theme.of(context).colorScheme.primary,
        dateRange: '${days.format(review.weekStart)} – ${days.format(last)}',
        takeaway: WeeklyReviewView.takeawayText(l10n, review.takeaway, locale),
        sessions: l10n.weeklyReviewOfGoal(review.sessionCount, review.goal),
        volume:
            ShareCardContent.formatVolume(
              review.volumeKg,
              unit: review.volumeUnit,
              locale: locale,
            ) ??
            AppFormat.weight(
              0,
              WorkoutText.weightUnit(review.volumeUnit),
              locale: locale,
            ),
        records: [
          for (final record in review.personalRecords)
            [
              record.exerciseName,
              WorkoutText.recordDetail(l10n, record, locale: locale),
            ].join(' '),
        ],
      ),
      size: WeeklyReviewShareCard.size,
    );
    if (!mounted) return;
    setState(() => _sharing = false);
    if (png == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.weeklyReviewShareFailed}. ${l10n.socialTryAgain}',
            ),
          ),
        );
      return;
    }
    await shareSheet.shareImage(context, png, name: 'compound-week.png');
  }

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(AppSymbols.share),
    tooltip: context.l10n.weeklyReviewShare,
    onPressed: _sharing ? null : () => unawaited(_share()),
  );
}
