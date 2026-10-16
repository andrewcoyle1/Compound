import 'package:bloc_test/bloc_test.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/check_in/check_in.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const uid = StagingData.uid;
  final weekStart = DateTime(2026, 10, 12);

  late StagingData data;
  late AnalyticsRecorder analytics;
  late ProposalDismissals dismissals;

  setUp(() {
    data = StagingData();
    analytics = AnalyticsRecorder();
    dismissals = ProposalDismissals();
  });

  WeeklyCheckInBloc build() => WeeklyCheckInBloc(
    users: data.users,
    nutrition: data.nutrition,
    body: data.body,
    checkIns: data.checkIns,
    programs: data.programs,
    analytics: analytics,
    dismissals: dismissals,
    uid: uid,
    weekStart: weekStart,
    now: () => data.now,
    newId: () => 'weigh-in',
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group(WeeklyCheckInBloc, () {
    test('opens loading', () {
      expect(build().state.status, WeeklyCheckInStatus.loading);
      expect(build().state.currentStep, isNull);
    });

    blocTest<WeeklyCheckInBloc, WeeklyCheckInState>(
      'builds the steps that have something to ask',
      build: build,
      act: (bloc) => bloc.add(const WeeklyCheckInStarted()),
      verify: (bloc) {
        final state = bloc.state;
        expect(state.status, WeeklyCheckInStatus.ready);
        expect(state.flow!.steps, [
          CheckInStep.introduction,
          CheckInStep.partialLogging,
          CheckInStep.loggingBreak,
          CheckInStep.programUpdate,
        ]);
        expect(state.currentStep, CheckInStep.introduction);
        expect(state.partialRows, hasLength(7));
        expect(state.figures!.proposal, isNotNull);
        // The latest weigh-in, in kilograms.
        expect(state.weighIn.kilograms, inInclusiveRange(69, 71));
        expect(analytics.names.take(2), [
          'CheckInView_Appear',
          'CheckInView_Step_Shown',
        ]);
        expect(analytics.parameters('CheckInView_Appear'), {
          'check_in_week_start': weekStart,
          'check_in_steps':
              'introduction,partialLogging,loggingBreak,programUpdate',
          'check_in_step_count': 4,
        });
      },
    );

    test('walks the flow, saving each answer, and completes', () async {
      final bloc = build()..add(const WeeklyCheckInStarted());
      await settle();
      bloc.add(const WeeklyCheckInContinuePressed());
      await settle();
      expect(bloc.state.currentStep, CheckInStep.partialLogging);

      final day = bloc.state.partialRows.first.dayKey;
      bloc
        ..add(WeeklyCheckInPartialToggled(day, on: true))
        ..add(const WeeklyCheckInContinuePressed());
      await settle();
      expect(bloc.state.currentStep, CheckInStep.loggingBreak);
      final annotations = await data.checkIns.watchDayAnnotations(uid).first;
      expect(
        annotations.firstWhere((a) => a.dayKey == day).isPartiallyLogged,
        isTrue,
      );

      bloc.add(const WeeklyCheckInContinuePressed());
      await settle();
      expect(bloc.state.currentStep, CheckInStep.programUpdate);

      final proposal = bloc.state.figures!.proposal!;
      dismissals.dismiss(uid, 1);
      bloc.add(const WeeklyCheckInAcceptPressed());
      await settle();
      expect(bloc.state.status, WeeklyCheckInStatus.finished);
      final plan = (await data.nutrition.watchDietPlan(uid).first)!;
      final mean =
          plan.days.map((day) => day.calories).reduce((a, b) => a + b) / 7;
      // The active mesocycle's training days vary the days a little.
      expect(mean, closeTo(proposal.proposedTargetKcal, 1));
      expect(plan.calorieDistribution, 'varied');
      expect(dismissals.of(uid), isNull);
      final record = await data.checkIns.watchCheckInRecord(uid).first;
      expect(record!.lastCompletedWeekStart, weekStart);
      expect(
        analytics.names,
        containsAllInOrder([
          'CheckInView_Step_Completed',
          'CheckInView_SaveAnswer_Start',
          'CheckInView_SaveAnswer_Success',
          'CheckInView_Proposal_Accept',
          'CheckInView_Completed',
          'CheckInView_Complete_Success',
        ]),
      );
      expect(analytics.parameters('CheckInView_SaveAnswer_Success'), {
        'action': 'accept_proposal',
      });
      await bloc.close();
      expect(analytics.parameters('CheckInView_Disappear'), {
        'step': 'programUpdate',
        'check_in_completed': true,
      });
    });

    test('Done finishes without a new plan', () async {
      data = StagingData(withPlan: false);
      final bloc = build()..add(const WeeklyCheckInStarted());
      await settle();
      for (var i = 0; i < 3; i++) {
        bloc.add(const WeeklyCheckInContinuePressed());
        await settle();
      }
      expect(bloc.state.figures!.proposal, isNull);
      // Accept does nothing without a proposal.
      bloc.add(const WeeklyCheckInAcceptPressed());
      await settle();
      expect(bloc.state.currentStep, CheckInStep.programUpdate);
      bloc.add(const WeeklyCheckInDonePressed());
      await settle();
      expect(bloc.state.status, WeeklyCheckInStatus.finished);
      expect(analytics.parameters('CheckInView_Step_Completed'), {
        'step': 'programUpdate',
        'check_in_step_outcome': 'done',
      });
    });

    test('asks for a weigh-in when none is recent, and logs it', () async {
      data = StagingData(measurements: const []);
      final bloc = build()..add(const WeeklyCheckInStarted());
      await settle();
      expect(bloc.state.flow!.steps, contains(CheckInStep.weighIn));
      // From the profile's 70 kg.
      expect(bloc.state.weighIn.kilograms, 70);
      bloc.add(const WeeklyCheckInContinuePressed());
      await settle();
      bloc.add(const WeeklyCheckInContinuePressed());
      await settle();
      expect(bloc.state.currentStep, CheckInStep.weighIn);
      bloc
        ..add(const WeeklyCheckInUnitChanged(WeightUnitPreference.pounds))
        ..add(const WeeklyCheckInWholeChanged(160))
        ..add(const WeeklyCheckInTenthsChanged(5))
        ..add(const WeeklyCheckInLogWeightPressed());
      await settle();
      expect(bloc.state.currentStep, isNot(CheckInStep.weighIn));
      final measurements = await data.body.watchMeasurements(uid).first;
      expect(measurements.single.id, 'weigh-in');
      expect(measurements.single.weightKg, closeTo(160.5 / 2.20462, 1e-9));
      final user = await data.users.watchUser(uid).first;
      expect(user!.submittedWeightUnitPreference, WeightUnitPreference.pounds);
      expect(analytics.names, contains('CheckInView_LogWeight_Success'));
      expect(bloc.state.weighInsSaved, 1);
    });

    test('skipping the weigh-in moves on', () async {
      data = StagingData(measurements: const []);
      final bloc = build()..add(const WeeklyCheckInStarted());
      await settle();
      bloc.add(const WeeklyCheckInContinuePressed());
      await settle();
      bloc.add(const WeeklyCheckInContinuePressed());
      await settle();
      bloc.add(const WeeklyCheckInSkipWeighInPressed());
      await settle();
      expect(bloc.state.currentStep, isNot(CheckInStep.weighIn));
      expect(analytics.parameters('CheckInView_Step_Completed'), {
        'step': 'weighIn',
        'check_in_step_outcome': 'skipped',
      });
    });

    test('asks about unlogged days and saves fasts', () async {
      final meals = [
        ...sampleMealLogs(uid: uid, now: stagingNow),
        ...sampleMealHistory(uid: uid, now: stagingNow),
      ];
      // Nothing logged four days ago.
      final gap = localDayKey(DateTime(2026, 10, 11));
      data = StagingData(
        meals: [
          for (final meal in meals)
            if (meal.dayKey != gap) meal,
        ],
      );
      final bloc = build()..add(const WeeklyCheckInStarted());
      await settle();
      expect(bloc.state.flow!.steps, contains(CheckInStep.fasting));
      while (bloc.state.currentStep != CheckInStep.fasting) {
        bloc.add(const WeeklyCheckInContinuePressed());
        await settle();
      }
      expect(bloc.state.fastingRows.single.dayKey, gap);
      bloc
        ..add(WeeklyCheckInFastingToggled(gap, on: true))
        ..add(const WeeklyCheckInContinuePressed());
      await settle();
      final annotations = await data.checkIns.watchDayAnnotations(uid).first;
      expect(
        annotations.firstWhere((a) => a.dayKey == gap).isFastingDay,
        isTrue,
      );
    });

    test('starts and ends a logging break', () async {
      final bloc = build()..add(const WeeklyCheckInStarted());
      await settle();
      bloc.add(const WeeklyCheckInContinuePressed());
      await settle();
      bloc.add(const WeeklyCheckInContinuePressed());
      await settle();
      bloc.add(const WeeklyCheckInStartBreakPressed());
      await settle();
      expect(bloc.state.figures!.openLoggingBreak, isNotNull);
      expect(bloc.state.figures!.proposal, isNull);
      expect(bloc.state.currentStep, CheckInStep.programUpdate);

      // A second check-in, on the break, offers to end it.
      final second = build()..add(const WeeklyCheckInStarted());
      await settle();
      while (second.state.currentStep != CheckInStep.loggingBreak) {
        second.add(const WeeklyCheckInContinuePressed());
        await settle();
      }
      second.add(const WeeklyCheckInEndBreakPressed());
      await settle();
      expect(second.state.figures!.openLoggingBreak, isNull);
      final loggingBreak = await data.checkIns.watchLoggingBreak(uid).first;
      expect(loggingBreak!.endDate, data.now);
    });

    test('stays on the step with an alert when a save fails', () async {
      data = StagingData(checkIns: _FailingCheckIns(StagingData().checkIns));
      final bloc = build()..add(const WeeklyCheckInStarted());
      await settle();
      bloc.add(const WeeklyCheckInContinuePressed());
      await settle();
      bloc.add(const WeeklyCheckInContinuePressed());
      await settle();
      expect(bloc.state.currentStep, CheckInStep.partialLogging);
      expect(bloc.state.alert, WeeklyCheckInAlert.saveFailed);
      expect(bloc.state.alertId, 1);
      expect(bloc.state.isSaving, isFalse);
      expect(analytics.parameters('CheckInView_SaveAnswer_Fail'), {
        'action': 'save_annotations',
        'error_description': 'Exception: refused',
      });
    });

    test('alerts when completing fails', () async {
      data = StagingData(
        withPlan: false,
        checkIns: _FailingCheckIns(StagingData().checkIns),
      );
      final bloc = build()..add(const WeeklyCheckInStarted());
      await settle();
      bloc.add(const WeeklyCheckInContinuePressed());
      await settle();
      // The partial step fails to save; skip past it by hand.
      bloc.emit(bloc.state.copyWith(stepIndex: 3));
      bloc.add(const WeeklyCheckInDonePressed());
      await settle();
      expect(bloc.state.alert, WeeklyCheckInAlert.completeFailed);
      expect(bloc.state.status, WeeklyCheckInStatus.ready);
    });

    test('alerts when the weigh-in fails', () async {
      data = StagingData(measurements: const []);
      final failing = WeeklyCheckInBloc(
        users: _FailingUsers(),
        nutrition: data.nutrition,
        body: data.body,
        checkIns: data.checkIns,
        programs: data.programs,
        analytics: analytics,
        dismissals: dismissals,
        uid: uid,
        weekStart: weekStart,
        now: () => data.now,
      )..add(const WeeklyCheckInStarted());
      await settle();
      failing.emit(failing.state.copyWith(stepIndex: 2));
      expect(failing.state.currentStep, CheckInStep.weighIn);
      failing.add(const WeeklyCheckInLogWeightPressed());
      await settle();
      expect(failing.state.alert, WeeklyCheckInAlert.logWeightFailed);
      expect(failing.state.currentStep, CheckInStep.weighIn);
    });

    test('shows a failure when the meals cannot be read', () async {
      final bloc = WeeklyCheckInBloc(
        users: data.users,
        nutrition: _FailingNutrition(),
        body: data.body,
        checkIns: data.checkIns,
        programs: data.programs,
        analytics: analytics,
        dismissals: dismissals,
        uid: uid,
        weekStart: weekStart,
      )..add(const WeeklyCheckInStarted());
      await settle();
      expect(bloc.state.status, WeeklyCheckInStatus.failure);
    });

    test('logs a dismissal with the step it left from', () async {
      final bloc = build()..add(const WeeklyCheckInStarted());
      await settle();
      bloc.add(const WeeklyCheckInDismissPressed());
      await settle();
      expect(analytics.parameters('CheckInView_Dismissed'), {
        'step': 'introduction',
      });
      // Nothing pressed before the flow is built does anything.
      final early = build()..add(const WeeklyCheckInContinuePressed());
      await settle();
      expect(early.state.currentStep, isNull);
      await early.close();
      expect(analytics.parameters('CheckInView_Disappear'), {
        'step': 'none',
        'check_in_completed': false,
      });
    });
  });
}

/// Reads through to [_inner], and refuses every write.
class _FailingCheckIns implements CheckInRepository {
  new(this._inner);

  final CheckInRepository _inner;

  @override
  Stream<NutritionStrategySettings> watchStrategySettings(String uid) =>
      _inner.watchStrategySettings(uid);

  @override
  Stream<List<NutritionDayAnnotation>> watchDayAnnotations(String uid) =>
      _inner.watchDayAnnotations(uid);

  @override
  Stream<LoggingBreak?> watchLoggingBreak(String uid) =>
      _inner.watchLoggingBreak(uid);

  @override
  Stream<CheckInRecord?> watchCheckInRecord(String uid) =>
      _inner.watchCheckInRecord(uid);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<void>.error(Exception('refused'));
}

class _FailingUsers extends InMemoryUserRepository {
  new() : super(users: {StagingData.uid: sampleUser(now: stagingNow)});

  @override
  Future<void> updateUserFields(String uid, List<UserFieldValue> fields) =>
      Future.error(Exception('refused'));
}

class _FailingNutrition extends InMemoryNutritionRepository {
  @override
  Stream<List<MealLogModel>> watchMeals(
    String uid, {
    bool includeHiddenHealthImports = false,
  }) => Stream.error(Exception('offline'));
}
