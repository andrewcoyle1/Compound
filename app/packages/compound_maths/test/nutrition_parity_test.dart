// The nutrition port against the fixture NutritionParityTests.swift records
// from the real Swift, with the same tolerance.
import 'dart:convert';
import 'dart:io';

import 'package:compound_maths/compound_maths.dart';
import 'package:test/test.dart';

import 'parity_test.dart' show Json, mismatch;

const _fixturePath =
    '../../../CompoundUnitTests/Fixtures/nutrition-parity.json';

double? _double(Object? value) => (value as num?)?.toDouble();

/// The active goal's signed rate and target weight; nulls without one.
({double? rate, double? weight}) _goal(Object? raw) {
  final goal = raw as Json?;
  if (goal == null || goal['status'] != 'active') {
    return (rate: null, weight: null);
  }
  return (
    rate: signedWeeklyChangeKg(
      startingWeightKg: _double(goal['startingWeightKg'])!,
      targetWeightKg: _double(goal['targetWeightKg'])!,
      weeklyChangeKg: _double(goal['weeklyChangeKg'])!,
    ),
    weight: _double(goal['targetWeightKg']),
  );
}

Json _macros(Macros m) => {
  'calories': m.calories,
  'proteinGrams': m.proteinGrams,
  'carbGrams': m.carbGrams,
  'fatGrams': m.fatGrams,
};

Object? _outcome(TargetOutcome? outcome) => switch (outcome) {
  null => null,
  TargetProposal() => {
    'kind': 'proposal',
    'expenditureKcal': outcome.expenditureKcal,
    'currentTargetKcal': outcome.currentTargetKcal,
    'proposedTargetKcal': outcome.proposedTargetKcal,
    'weeklyTrendChangeKg': outcome.weeklyTrendChangeKg,
    'goalWeeklyChangeKg': outcome.goalWeeklyChangeKg,
  },
  AdherenceNote() => {
    'kind': 'adherence',
    'targetKcal': outcome.targetKcal,
    'recentIntakeKcal': outcome.recentIntakeKcal,
    'weeklyTrendChangeKg': outcome.weeklyTrendChangeKg,
    'goalWeeklyChangeKg': outcome.goalWeeklyChangeKg,
  },
};

Object? targetProposalCase(Json c) {
  final e = c['estimate'] as Json;
  final estimate = ExpenditureEstimate(
    day: e['day'] as String,
    kcal: _double(e['kcal'])!,
    source: ExpenditureSource.values.byName(e['source'] as String),
    isProvisional: e['isProvisional'] as bool,
    trendWeightKg: 80,
    weeklyTrendChangeKg: _double(e['weeklyTrendChangeKg']),
    loggedDays: 24,
    weighInCount: 20,
    windowDays: 28,
    stepAdjustmentKcal: 0,
    sdKcal: _double(e['sdKcal']),
    weeklyTrendChangeSDKg: null,
    recentIntakeKcal: _double(e['recentIntakeKcal']),
  );
  final p = c['plan'] as Json?;
  final plan = p == null
      ? null
      : (
          dayCalories: [
            for (final kcal in p['dayCalories'] as List)
              (kcal as num).toDouble(),
          ],
          createdDay: p['createdDay'] as String,
        );
  final mode = ExpenditureCalculationMode.values.byName(
    c['calculationMode'] as String,
  );
  final gender = Gender.tryParse(c['gender'] as String?);
  final kcalPerKg = _double(c['kcalPerKg'])!;
  final rate = _goal(c['goal']).rate;
  return {
    'outcome': _outcome(
      evaluateTarget(
        estimate: estimate,
        plan: plan,
        goalWeeklyChangeKg: rate,
        calculationMode: mode,
        kcalPerKg: kcalPerKg,
        gender: gender,
      ),
    ),
    'shownProposedTargetKcal': proposeTarget(
      estimate: estimate,
      plan: plan,
      goalWeeklyChangeKg: rate,
      calculationMode: mode,
      kcalPerKg: kcalPerKg,
      gender: gender,
      dismissedKcal: _double(c['dismissedKcal']),
    )?.proposedTargetKcal,
  };
}

Object? checkInCase(Json c) {
  final b = c['loggingBreak'] as Json?;
  final today = c['today'] as String;
  final state = checkInState(
    today: today,
    checkInWeekday: c['checkInWeekday'] as int,
    lastCompletedWeekStart: c['lastCompletedWeekStart'] as String?,
    lastSkippedWeekStart: c['lastSkippedWeekStart'] as String?,
    loggingBreak: b == null
        ? null
        : (startDay: b['startDay'] as String, endDay: b['endDay'] as String?),
  );
  return {
    'state': state.name,
    'dueWeekStart': state == CheckInState.due ? checkInWeekStart(today) : null,
    'weekStart': checkInWeekStart(today),
  };
}

Object? dietPlanCase(Json c) {
  final goal = _goal(c['goal']);
  return [
    for (final day in dietPlanDays(
      expenditureKcal: _double(c['expenditureKcal'])!,
      targetKcal: _double(c['targetKcal']),
      goalWeeklyChangeKg: goal.rate,
      goalWeightKg: goal.weight,
      gender: Gender.tryParse(c['gender'] as String?),
      weightKg: _double(c['weightKg']),
      heightCm: _double(c['heightCm']),
      ageYears: c['ageYears'] as int?,
      diet: PreferredDiet.tryParse(c['diet'] as String)!,
      distribution: CalorieDistribution.tryParse(c['distribution'] as String)!,
      protein: ProteinIntake.tryParse(c['protein'] as String)!,
      trainingDaysPerWeek: c['trainingDaysPerWeek'] as int,
    ))
      _macros(day),
  ];
}

final _cases = <String, Object? Function(Json)>{
  'calorieFloor': (c) => calorieFloor(Gender.tryParse(c['gender'] as String?)),
  'signedWeeklyChange': (c) => signedWeeklyChangeKg(
    startingWeightKg: _double(c['startingWeightKg'])!,
    targetWeightKg: _double(c['targetWeightKg'])!,
    weeklyChangeKg: _double(c['weeklyChangeKg'])!,
  ),
  'goalTarget': (c) => goalTargetKcal(
    expenditureKcal: _double(c['expenditureKcal'])!,
    goalWeeklyChangeKg: _goal(c['goal']).rate,
  ),
  'referenceWeight': (c) => referenceWeightKg(
    weightKg: _double(c['weightKg'])!,
    heightCm: _double(c['heightCm']),
    goalWeightKg: _double(c['goalWeightKg']),
  ),
  'proteinGrams': (c) => proteinGrams(
    intake: ProteinIntake.tryParse(c['intake'] as String)!,
    referenceWeightKg: _double(c['referenceWeightKg'])!,
    ageYears: c['ageYears'] as int?,
  ),
  'macros': (c) => _macros(
    dailyMacros(
      calories: _double(c['calories'])!,
      proteinGrams: _double(c['proteinGrams'])!,
      diet: PreferredDiet.tryParse(c['diet'] as String)!,
      referenceWeightKg: _double(c['referenceWeightKg'])!,
    ),
  ),
  'highDayIndices': (c) => highDayIndices(c['count'] as int),
  'dailyCalories': (c) => dailyCalories(
    target: _double(c['target'])!,
    floor: _double(c['floor'])!,
    distribution: CalorieDistribution.tryParse(c['distribution'] as String)!,
    trainingDaysPerWeek: c['trainingDaysPerWeek'] as int,
  ),
  'dietPlan': dietPlanCase,
  'targetProposal': targetProposalCase,
  'checkIn': checkInCase,
  'macroRemaining': (c) => macroRemaining(
    total: _double(c['total'])!,
    target: _double(c['target'])!,
    showOverages: c['showOverages'] as bool,
  ),
};

void main() {
  final fixture =
      jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;

  test('the fixture has every section and nothing else', () {
    expect(fixture.keys.toSet(), _cases.keys.toSet());
  });

  for (final MapEntry(key: section, value: run) in _cases.entries) {
    test('$section matches the Swift', () {
      final cases = (fixture[section] as List).cast<Json>();
      expect(cases, isNotEmpty);
      for (final (index, c) in cases.indexed) {
        final m = mismatch(run(c), c['expected'], '$section[$index]');
        expect(m, isNull, reason: m);
      }
    });
  }
}
