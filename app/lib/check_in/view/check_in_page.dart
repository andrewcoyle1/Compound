import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/bloc/weekly_check_in_bloc.dart';
import 'package:compound/coach/coach.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:health_repository/health_repository.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:user_repository/user_repository.dart';

/// The weekly check-in (Swift `CheckInView`), over the tabs as Swift's
/// sheet: one step at a time, its choices pinned under it. Opened from
/// Today and the Nutrition Overview with the week it reviews.
class CheckInPage extends StatelessWidget {
  const new({required this.weekStart, super.key, this.now});

  static const path = '/check-in';
  static const name = 'checkIn';

  /// The `yyyy-MM-dd` Monday of the week reviewed.
  static const weekParameter = 'week';

  /// Opens the check-in for the week starting [weekStart].
  static Future<void> show(BuildContext context, DateTime weekStart) =>
      context.pushNamed(
        name,
        queryParameters: {weekParameter: localDayKey(weekStart)},
      );

  /// The ISO week the check-in reviews, which completing it records.
  final DateTime weekStart;

  /// The moment the check-in runs at; now when null. For tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    // The router only shows this page while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => WeeklyCheckInBloc(
        users: context.read<UserRepository>(),
        nutrition: context.read<NutritionRepository>(),
        body: context.read<BodyRepository>(),
        health: context.read<HealthRepository>(),
        checkIns: context.read<CheckInRepository>(),
        programs: context.read<ProgramRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        dismissals: context.read<ProposalDismissals>(),
        uid: state.user.uid,
        weekStart: weekStart,
        now: now ?? DateTime.now,
      )..add(const WeeklyCheckInStarted()),
      child: const CheckInView(),
    );
  }
}

class CheckInView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<WeeklyCheckInBloc>().state;
    final step = state.currentStep;
    return MultiBlocListener(
      listeners: [
        // `playHaptic(.success)` after the weigh-in saves.
        BlocListener<WeeklyCheckInBloc, WeeklyCheckInState>(
          listenWhen: (previous, current) =>
              previous.weighInsSaved != current.weighInsSaved,
          listener: (_, _) => unawaited(HapticFeedback.successNotification()),
        ),
        BlocListener<WeeklyCheckInBloc, WeeklyCheckInState>(
          listener: (context, state) {
            if (state.status == WeeklyCheckInStatus.finished) {
              unawaited(HapticFeedback.successNotification());
              _close(context);
              return;
            }
            final alert = state.alert;
            if (alert == null) return;
            unawaited(HapticFeedback.errorNotification());
            unawaited(
              showFailureAlert(context, switch (alert) {
                WeeklyCheckInAlert.logWeightFailed =>
                  l10n.checkInLogWeightFailed,
                WeeklyCheckInAlert.saveFailed => l10n.checkInSaveFailed,
                WeeklyCheckInAlert.completeFailed => l10n.checkInCompleteFailed,
              }, l10n.checkInTryAgain),
            );
          },
          listenWhen: (previous, current) =>
              previous.alertId != current.alertId ||
              (previous.status != current.status &&
                  current.status == WeeklyCheckInStatus.finished),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          leading: CloseButton(
            onPressed: () {
              context.read<WeeklyCheckInBloc>().add(
                const WeeklyCheckInDismissPressed(),
              );
              _close(context);
            },
          ),
          title: Text(step == null ? l10n.checkInTitle : stepTitle(l10n, step)),
          actions: [
            AskCoachButton(
              CoachContext(
                kind: CoachContextKind.checkIn,
                date: localDayKey(state.weekStart),
                title: l10n.checkInTitle,
              ),
            ),
          ],
        ),
        body: switch (state.status) {
          WeeklyCheckInStatus.failure => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                l10n.checkInSaveFailed,
                style: AppTextStyles.sectionTitle,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          _ when step == null => const Center(
            child: CircularProgressIndicator.adaptive(),
          ),
          _ => _Step(state: state, step: step),
        },
        bottomNavigationBar: step == null
            ? null
            : _Actions(state: state, step: step),
      ),
    );
  }

  /// Back to wherever it was opened from; to Today when opened directly.
  static void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppTab.today.path);
    }
  }
}

/// A step's title (`CheckInStep.title`).
String stepTitle(AppLocalizations l10n, CheckInStep step) => switch (step) {
  CheckInStep.introduction => l10n.checkInStepIntroduction,
  CheckInStep.partialLogging => l10n.checkInStepPartialLogging,
  CheckInStep.weighIn => l10n.checkInStepWeighIn,
  CheckInStep.fasting => l10n.checkInStepFasting,
  CheckInStep.loggingBreak => l10n.checkInStepLoggingBreak,
  CheckInStep.programUpdate => l10n.checkInStepProgramUpdate,
};

/// A failed write's alert, Swift's `showFailure`.
Future<void> showFailureAlert(
  BuildContext context,
  String title, [
  String? message,
]) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(title),
    content: message == null ? null : Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(MaterialLocalizations.of(context).okButtonLabel),
      ),
    ],
  ),
);

class _Step extends StatelessWidget {
  const new({required this.state, required this.step});

  final WeeklyCheckInState state;
  final CheckInStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final bloc = context.read<WeeklyCheckInBloc>();
    final flow = state.flow!;
    final figures = state.figures;
    final secondary = AppTextStyles.rowDetail.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final trend =
        ExpenditureText.trendChange(
          l10n,
          figures?.current.weeklyTrendChangeKg,
          locale: locale,
        ) ??
        l10n.checkInNotEnoughData;
    Widget detail(String text) => Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Text(text, style: secondary),
    );
    Widget day(CheckInDay row, {required ValueChanged<bool> onChanged}) =>
        AppListRowToggle(
          title: DateFormat.EEEE(locale).format(localMidnight(row.dayKey)),
          subtitle: switch (row.intakeKcal) {
            null => l10n.checkInNothingLogged,
            final kcal => AppFormat.kcal(kcal.round(), locale: locale),
          },
          value: row.isOn,
          onChanged: onChanged,
        );
    final children = switch (step) {
      CheckInStep.introduction => [
        MethodInfoHeader(
          title: l10n.checkInLastSevenDays,
          info: MethodInfo.weightTrend(l10n),
        ),
        AppSection(
          children: [
            AppListRow(
              title: l10n.checkInDaysLogged,
              accessory: AppListRowValue(
                l10n.checkInDaysLoggedValue(flow.loggedDayCount),
              ),
            ),
            AppListRow(
              title: l10n.checkInWeighIns,
              accessory: AppListRowValue(
                AppFormat.number(flow.weighInCount, locale: locale),
              ),
            ),
            AppListRow(
              title: l10n.checkInWeightTrend,
              accessory: AppListRowValue(trend),
            ),
          ],
        ),
      ],
      CheckInStep.partialLogging => [
        MethodInfoHeader(
          title: l10n.checkInPartialHeader,
          info: MethodInfo.checkInRules(l10n),
        ),
        AppSection(
          footer: l10n.checkInPartialFooter,
          children: [
            for (final row in state.partialRows)
              day(
                row,
                onChanged: (on) =>
                    bloc.add(WeeklyCheckInPartialToggled(row.dayKey, on: on)),
              ),
          ],
        ),
      ],
      CheckInStep.weighIn => [
        AppSection(children: [detail(l10n.checkInWeighInPrompt)]),
        const SizedBox(height: AppSpacing.l),
        WeightWheels(
          state: state.weighIn,
          onUnitChanged: (unit) => bloc.add(WeeklyCheckInUnitChanged(unit)),
          onWholeChanged: (whole) => bloc.add(WeeklyCheckInWholeChanged(whole)),
          onTenthsChanged: (tenths) =>
              bloc.add(WeeklyCheckInTenthsChanged(tenths)),
        ),
      ],
      CheckInStep.fasting => [
        MethodInfoHeader(
          title: l10n.checkInFastingHeader,
          info: MethodInfo.checkInRules(l10n),
        ),
        AppSection(
          footer: l10n.checkInFastingFooter,
          children: [
            for (final row in state.fastingRows)
              day(
                row,
                onChanged: (on) =>
                    bloc.add(WeeklyCheckInFastingToggled(row.dayKey, on: on)),
              ),
          ],
        ),
      ],
      CheckInStep.loggingBreak => [
        if (figures?.openLoggingBreak != null)
          AppSection(
            header: l10n.checkInOnBreakHeader,
            children: [detail(l10n.checkInOnBreakDetail)],
          )
        else
          AppSection(
            header: l10n.checkInTakeBreakHeader,
            children: [detail(l10n.checkInTakeBreakDetail)],
          ),
      ],
      CheckInStep.programUpdate => [
        ...switch ((figures?.proposal, figures?.adherenceNote)) {
          (final proposal?, _) => [
            MethodInfoHeader(
              title: l10n.checkInNewTargets,
              info: MethodInfo.targetProposal(l10n),
            ),
            AppSection(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Text(
                    ExpenditureText.proposal(l10n, proposal, locale: locale),
                    style: AppTextStyles.rowDetail,
                  ),
                ),
              ],
            ),
          ],
          (null, final note) => [
            if (note != null) ...[
              MethodInfoHeader(
                title: l10n.checkInAboutIntake,
                info: MethodInfo.targetProposal(l10n),
              ),
              AppSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Text(
                      ExpenditureText.adherence(l10n, note, locale: locale),
                      style: AppTextStyles.rowDetail,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            MethodInfoHeader(
              title: l10n.checkInTargetsUnchanged,
              info: MethodInfo.adaptiveExpenditure(l10n),
            ),
            AppSection(
              children: [
                AppListRow(
                  title: l10n.expenditureTitle,
                  accessory: figures == null
                      ? null
                      : AppListRowValue(
                          ExpenditureText.expenditure(
                            l10n,
                            figures.current,
                            locale: locale,
                          ),
                        ),
                ),
                AppListRow(
                  title: l10n.checkInWeightTrend,
                  accessory: AppListRowValue(trend),
                ),
              ],
            ),
          ],
        },
      ],
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.s,
          children: children,
        ),
      ],
    );
  }
}

/// Each step's choices, pinned under it (`actions`).
class _Actions extends StatelessWidget {
  const new({required this.state, required this.step});

  final WeeklyCheckInState state;
  final CheckInStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<WeeklyCheckInBloc>();
    Widget button(
      String label,
      WeeklyCheckInEvent event, {
      bool primary = true,
    }) => AppCtaButton(
      label: label,
      variant: primary ? AppCtaVariant.primary : AppCtaVariant.secondary,
      isLoading: primary && state.isSaving,
      onPressed: state.isSaving ? null : () => bloc.add(event),
    );
    final onBreak = state.figures?.openLoggingBreak != null;
    return AppBottomCta(
      children: switch (step) {
        CheckInStep.introduction ||
        CheckInStep.partialLogging ||
        CheckInStep.fasting => [
          button(l10n.checkInContinue, const WeeklyCheckInContinuePressed()),
        ],
        CheckInStep.weighIn => [
          button(l10n.checkInLogWeight, const WeeklyCheckInLogWeightPressed()),
          button(
            l10n.checkInSkip,
            const WeeklyCheckInSkipWeighInPressed(),
            primary: false,
          ),
        ],
        CheckInStep.loggingBreak when onBreak => [
          button(l10n.checkInEndBreak, const WeeklyCheckInEndBreakPressed()),
          button(
            l10n.checkInStayOnBreak,
            const WeeklyCheckInContinuePressed(),
            primary: false,
          ),
        ],
        CheckInStep.loggingBreak => [
          button(l10n.checkInNoThanks, const WeeklyCheckInContinuePressed()),
          button(
            l10n.checkInStartBreak,
            const WeeklyCheckInStartBreakPressed(),
            primary: false,
          ),
        ],
        CheckInStep.programUpdate when state.figures?.proposal != null => [
          button(l10n.checkInAccept, const WeeklyCheckInAcceptPressed()),
          button(
            l10n.checkInNotNow,
            const WeeklyCheckInDonePressed(),
            primary: false,
          ),
        ],
        CheckInStep.programUpdate => [
          button(l10n.checkInDone, const WeeklyCheckInDonePressed()),
        ],
      },
    );
  }
}
