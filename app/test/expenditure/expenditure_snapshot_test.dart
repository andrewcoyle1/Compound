import 'dart:async';
import 'dart:io';

import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../helpers/helpers.dart';

class _MockCheckIns extends Mock implements CheckInRepository;

void main() {
  const uid = StagingData.uid;

  Stream<ExpenditureSnapshot> watch(StagingData data) => watchExpenditure(
    uid: uid,
    users: data.users,
    nutrition: data.nutrition,
    body: data.body,
    checkIns: data.checkIns,
  );

  group('watchExpenditure', () {
    test('emits once everything has arrived, and on every change', () async {
      final data = StagingData();
      final snapshots = <ExpenditureSnapshot>[];
      final subscription = watch(data).listen(snapshots.add);
      await pumpEventQueue();
      expect(snapshots, hasLength(1));
      final first = snapshots.single;
      expect(first.user?.userId, uid);
      expect(first.meals, isNotEmpty);
      expect(first.measurements, isNotEmpty);
      expect(first.steps, isNotEmpty);
      expect(first.annotations, hasLength(1));
      expect(first.loggingBreak, isNotNull);
      expect(first.checkInRecord, isNotNull);
      expect(first.settings.stepInformedUpdates, isTrue);
      expect(first.dietPlan, isNotNull);
      expect(first.goal?.targetWeightKg, 68);

      await data.checkIns.markCheckInCompleted(uid, DateTime(2026, 10, 12));
      await pumpEventQueue();
      expect(
        snapshots.last.checkInRecord?.lastCompletedWeekStart,
        DateTime(2026, 10, 12),
      );
      await subscription.cancel();
    });

    test('passes on a failed read of the meals', () async {
      final data = StagingData();
      final nutrition = _ThrowingNutrition();
      final errors = <Object>[];
      final subscription = watchExpenditure(
        uid: uid,
        users: data.users,
        nutrition: nutrition,
        body: data.body,
        checkIns: data.checkIns,
      ).listen((_) {}, onError: errors.add);
      await pumpEventQueue();
      expect(errors, isNotEmpty);
      await subscription.cancel();
    });

    test('falls back to the defaults without the rest', () async {
      final data = StagingData();
      final checkIns = _MockCheckIns();
      Stream<T> fail<T>() => Stream<T>.error(Exception('offline'));
      when(() => checkIns.watchStrategySettings(uid)).thenAnswer((_) => fail());
      when(() => checkIns.watchDayAnnotations(uid)).thenAnswer((_) => fail());
      when(() => checkIns.watchLoggingBreak(uid)).thenAnswer((_) => fail());
      when(() => checkIns.watchCheckInRecord(uid)).thenAnswer((_) => fail());
      final users = _ThrowingUsers();
      final snapshot = await watchExpenditure(
        uid: uid,
        users: users,
        nutrition: _NoPlanNutrition(data.nutrition),
        body: data.body,
        checkIns: checkIns,
      ).first;
      expect(snapshot.user, isNull);
      expect(
        snapshot.settings.toFirestore(),
        const NutritionStrategySettings(authorId: uid).toFirestore(),
      );
      expect(snapshot.annotations, isEmpty);
      expect(snapshot.loggingBreak, isNull);
      expect(snapshot.checkInRecord, isNull);
      expect(snapshot.dietPlan, isNull);
      // The uid's goal, as Swift reads one with no goal id.
      expect(snapshot.goal, isNotNull);
    });

    test('a goal that cannot be read is none', () async {
      final data = StagingData();
      final snapshot = await watchExpenditure(
        uid: uid,
        users: data.users,
        nutrition: data.nutrition,
        body: _GoalFails(data.body),
        checkIns: data.checkIns,
      ).first;
      expect(snapshot.goal, isNull);
    });
  });

  group(ExpenditureFigures, () {
    late ExpenditureSnapshot snapshot;

    setUp(() async => snapshot = await watch(StagingData()).first);

    test("proposes lowering the staging user's target", () {
      final figures = ExpenditureFigures.of(snapshot, stagingNow);
      expect(figures.current.source, maths.ExpenditureSource.adaptive);
      expect(figures.history.last, figures.current);
      expect(figures.formulaKcal, greaterThan(figures.current.kcal));
      final proposal = figures.proposal!;
      expect(proposal.proposedTargetKcal, lessThan(proposal.currentTargetKcal));
      expect(figures.adherenceNote, isNull);
      expect(figures.checkInState, CheckInState.due);
      expect(figures.dueCheckInWeekStart, DateTime(2026, 10, 12));
      expect(figures.openLoggingBreak, isNull);
    });

    test('keeps a dismissed proposal away until it moves 50 kcal', () {
      final proposed = ExpenditureFigures.of(
        snapshot,
        stagingNow,
      ).proposal!.proposedTargetKcal;
      expect(
        ExpenditureFigures.of(
          snapshot,
          stagingNow,
          dismissedKcal: proposed + 49,
        ).proposal,
        isNull,
      );
      expect(
        ExpenditureFigures.of(
          snapshot,
          stagingNow,
          dismissedKcal: proposed + 50,
        ).proposal,
        isNotNull,
      );
    });

    test('proposes nothing during a break', () async {
      final data = StagingData(
        loggingBreaks: [
          LoggingBreak(authorId: uid, startDate: DateTime(2026, 10, 13)),
        ],
      );
      final figures = ExpenditureFigures.of(
        await watch(data).first,
        stagingNow,
      );
      expect(figures.openLoggingBreak, isNotNull);
      expect(figures.proposal, isNull);
      expect(figures.checkInState, CheckInState.inBreak);
      expect(figures.dueCheckInWeekStart, isNull);
      // Frozen where the break began.
      expect(figures.current.day, '2026-10-13');
    });

    test('a fixed estimate proposes nothing', () async {
      final data = StagingData(
        settings: const NutritionStrategySettings(
          authorId: uid,
          calculationMode: ExpenditureCalculationMode.fixed,
        ),
      );
      final figures = ExpenditureFigures.of(
        await watch(data).first,
        stagingNow,
      );
      expect(figures.proposal, isNull);
    });

    test('an inactive goal reads as maintenance', () {
      final abandoned = ExpenditureSnapshot(
        settings: snapshot.settings,
        user: snapshot.user,
        meals: snapshot.meals,
        measurements: snapshot.measurements,
        steps: snapshot.steps,
        annotations: snapshot.annotations,
        dietPlan: snapshot.dietPlan,
        goal: _goal(snapshot.goal!, status: GoalStatus.abandoned),
      );
      final losing = ExpenditureFigures.of(snapshot, stagingNow).proposal!;
      final maintaining = ExpenditureFigures.of(abandoned, stagingNow).proposal;
      expect(maintaining?.goalWeeklyChangeKg, isNot(losing.goalWeeklyChangeKg));
    });

    test('gives an adherence note to someone eating well over target', () {
      final plan = snapshot.dietPlan!;
      final low = DietPlan(
        planId: plan.planId,
        userId: plan.userId,
        createdAt: plan.createdAt,
        tdeeEstimate: plan.tdeeEstimate,
        preferredDiet: plan.preferredDiet,
        calorieFloor: plan.calorieFloor,
        trainingType: plan.trainingType,
        calorieDistribution: plan.calorieDistribution,
        proteinIntake: plan.proteinIntake,
        days: [
          for (var i = 0; i < 7; i++)
            const DailyMacroTarget(
              calories: 1900,
              proteinGrams: 150,
              carbGrams: 140,
              fatGrams: 50,
            ),
        ],
      );
      final figures = ExpenditureFigures.of(
        ExpenditureSnapshot(
          settings: snapshot.settings,
          user: snapshot.user,
          meals: snapshot.meals,
          measurements: snapshot.measurements,
          steps: snapshot.steps,
          annotations: snapshot.annotations,
          dietPlan: low,
          // Losing a third as fast as the goal asks.
          goal: _goal(snapshot.goal!, weeklyChangeKg: 1),
        ),
        stagingNow,
      );
      expect(figures.proposal, isNull);
      final note = figures.adherenceNote!;
      expect(note.targetKcal, 1900);
      expect(note.recentIntakeKcal, greaterThan(1900 * 1.1));
    });
  });

  test('acceptedPlan rebuilds the plan at the proposed target', () async {
    final snapshot = await watch(StagingData()).first;
    final proposal = ExpenditureFigures.of(snapshot, stagingNow).proposal!;
    final plan = acceptedPlan(
      plan: snapshot.dietPlan!,
      user: snapshot.user!,
      proposal: proposal,
      now: stagingNow,
    );
    final mean =
        plan.days.map((day) => day.calories).reduce((a, b) => a + b) / 7;
    expect(mean, closeTo(proposal.proposedTargetKcal, 1e-6));
    expect(plan.tdeeEstimate, proposal.expenditureKcal.roundToDouble());
    expect(plan.planId, uid);
    expect(plan.preferredDiet, snapshot.dietPlan!.preferredDiet);
    expect(plan.createdAt, stagingNow);
  });

  // GoalSummaryPresenter's applyToDietPlan (`CoreInteractor
  // .applyGoalToDietPlan`): the goal moves today's targets.
  group('goalAppliedPlan', () {
    late ExpenditureSnapshot snapshot;
    late maths.ExpenditureEstimate estimate;

    setUp(() async {
      snapshot = await watch(StagingData()).first;
      estimate = ExpenditureFigures.of(snapshot, stagingNow).current;
    });

    DietPlan applied(
      WeightGoal goal, {
      maths.ExpenditureEstimate? at,
      ExpenditureCalculationMode mode = ExpenditureCalculationMode.dynamic,
    }) => goalAppliedPlan(
      plan: snapshot.dietPlan!,
      user: snapshot.user!,
      goal: goal,
      estimate: at ?? estimate,
      calculationMode: mode,
      now: stagingNow,
    );

    double mean(DietPlan plan) =>
        plan.days.map((day) => day.calories).reduce((a, b) => a + b) / 7;

    test("builds on the engine's estimate and keeps the plan's answers", () {
      expect(estimate.isProvisional, isFalse);
      final plan = applied(snapshot.goal!);
      expect(plan.tdeeEstimate, estimate.kcal.roundToDouble());
      expect(plan.preferredDiet, snapshot.dietPlan!.preferredDiet);
      expect(plan.proteinIntake, snapshot.dietPlan!.proteinIntake);
      expect(plan.createdAt, stagingNow);
      // A faster rate eats less.
      final faster = applied(_goal(snapshot.goal!, weeklyChangeKg: 0.75));
      expect(mean(faster), lessThan(mean(plan)));
    });

    test(
      "a provisional estimate or fixed mode keeps the plan's expenditure",
      () {
        final provisional = maths.ExpenditureEstimate(
          day: estimate.day,
          kcal: estimate.kcal + 400,
          source: estimate.source,
          isProvisional: true,
          trendWeightKg: estimate.trendWeightKg,
          weeklyTrendChangeKg: estimate.weeklyTrendChangeKg,
          loggedDays: estimate.loggedDays,
          weighInCount: estimate.weighInCount,
          windowDays: estimate.windowDays,
          stepAdjustmentKcal: estimate.stepAdjustmentKcal,
          sdKcal: estimate.sdKcal,
          weeklyTrendChangeSDKg: estimate.weeklyTrendChangeSDKg,
          recentIntakeKcal: estimate.recentIntakeKcal,
        );
        final kept = snapshot.dietPlan!.tdeeEstimate;
        expect(applied(snapshot.goal!, at: provisional).tdeeEstimate, kept);
        expect(
          applied(
            snapshot.goal!,
            mode: ExpenditureCalculationMode.fixed,
          ).tdeeEstimate,
          kept,
        );
      },
    );

    test(
      'applyGoalToDietPlan saves it and forgets a dismissed proposal',
      () async {
        final data = StagingData();
        final dismissals = ProposalDismissals()..dismiss(uid, 2000);
        final goal = _goal(snapshot.goal!, weeklyChangeKg: 0.75);
        await applyGoalToDietPlan(
          goal,
          uid: uid,
          users: data.users,
          nutrition: data.nutrition,
          body: data.body,
          checkIns: data.checkIns,
          programs: data.programs,
          dismissals: dismissals,
          now: () => stagingNow,
        );
        final saved = await data.nutrition.watchDietPlan(uid).first;
        expect(saved!.createdAt, stagingNow);
        // The same week's calories, spread over the active program's
        // training days.
        expect(mean(saved), closeTo(mean(applied(goal)), 1));
        expect(saved.days.map((d) => d.calories).toSet().length, 2);
        expect(dismissals.of(uid), isNull);
      },
    );

    test('without a plan nothing is saved', () async {
      final data = StagingData(withPlan: false);
      final dismissals = ProposalDismissals()..dismiss(uid, 2000);
      await applyGoalToDietPlan(
        snapshot.goal!,
        uid: uid,
        users: data.users,
        nutrition: data.nutrition,
        body: data.body,
        checkIns: data.checkIns,
        programs: data.programs,
        dismissals: dismissals,
      );
      expect(await data.nutrition.watchDietPlan(uid).first, isNull);
      expect(dismissals.of(uid), 2000);
    });
  });

  test('proposalParameters names the proposal as Swift does', () {
    const proposal = maths.TargetProposal(
      expenditureKcal: 2500,
      currentTargetKcal: 2400,
      proposedTargetKcal: 2300,
      weeklyTrendChangeKg: null,
      goalWeeklyChangeKg: null,
    );
    expect(proposalParameters(proposal), {
      'proposal_current_kcal': 2400.0,
      'proposal_proposed_kcal': 2300.0,
      'proposal_expenditure_kcal': 2500.0,
      'proposal_reason': 'expenditureMoved',
    });
  });

  group(ProposalDismissals, () {
    late Directory directory;

    setUp(() => directory = Directory.systemTemp.createTempSync());
    tearDown(() => directory.deleteSync(recursive: true));

    test('remembers each account in memory', () {
      final dismissals = ProposalDismissals()..dismiss('a', 2300);
      expect(dismissals.of('a'), 2300);
      expect(dismissals.of('b'), isNull);
      dismissals.clear('a');
      expect(dismissals.of('a'), isNull);
    });

    test('keeps them in a file between launches', () {
      final file = File('${directory.path}/dismissed.json');
      ProposalDismissals(file: file).dismiss('a', 2300);
      expect(
        file.readAsStringSync(),
        '{"dismissedTargetProposalKcal.a":2300.0}',
      );
      final reopened = ProposalDismissals(file: file);
      expect(reopened.of('a'), 2300);
      reopened
        ..clear('b')
        ..clear('a');
      expect(ProposalDismissals(file: file).of('a'), isNull);
    });

    test('starts empty from a file it cannot read', () {
      final garbled = File('${directory.path}/garbled.json')
        ..writeAsStringSync('{');
      expect(ProposalDismissals(file: garbled).of('a'), isNull);
      final list = File('${directory.path}/list.json')
        ..writeAsStringSync('[1]');
      expect(ProposalDismissals(file: list).of('a'), isNull);
      final text = File('${directory.path}/text.json')
        ..writeAsStringSync('{"dismissedTargetProposalKcal.a":"x"}');
      expect(ProposalDismissals(file: text).of('a'), isNull);
    });
  });
}

class _ThrowingNutrition extends InMemoryNutritionRepository {
  @override
  Stream<List<MealLogModel>> watchMeals(
    String uid, {
    bool includeHiddenHealthImports = false,
  }) => Stream.error(Exception('offline'));
}

class _NoPlanNutrition extends InMemoryNutritionRepository {
  new(this._inner);

  final InMemoryNutritionRepository _inner;

  @override
  Stream<List<MealLogModel>> watchMeals(
    String uid, {
    bool includeHiddenHealthImports = false,
  }) => _inner.watchMeals(uid);

  @override
  Stream<DietPlan?> watchDietPlan(String uid) =>
      Stream.error(Exception('offline'));
}

class _ThrowingUsers extends InMemoryUserRepository {
  @override
  Stream<UserModel?> watchUser(String uid) =>
      Stream.error(Exception('offline'));
}

class _GoalFails extends InMemoryBodyRepository {
  new(this._inner);

  final InMemoryBodyRepository _inner;

  @override
  Stream<List<BodyMeasurementEntry>> watchMeasurements(String uid) =>
      _inner.watchMeasurements(uid);

  @override
  Stream<WeightGoal?> watchCurrentGoal(String uid, {String? currentGoalId}) =>
      Stream.error(Exception('offline'));
}

WeightGoal _goal(
  WeightGoal goal, {
  GoalStatus? status,
  double? weeklyChangeKg,
}) => WeightGoal(
  goalId: goal.goalId,
  userId: goal.userId,
  objective: goal.objective,
  startingWeightKg: goal.startingWeightKg,
  targetWeightKg: goal.targetWeightKg,
  weeklyChangeKg: weeklyChangeKg ?? goal.weeklyChangeKg,
  createdAt: goal.createdAt,
  status: status ?? goal.status,
);
