import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/onboarding/goal/goal_setup_cubit.dart';
import 'package:compound_models/compound_models.dart'
    show UserModelKeys, WeightGoalKeys;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';
import 'helpers.dart';

/// Mirrors `OnboardingGoalSettingPresenterTests` and
/// `OnboardingGoalSummaryPresenterTests`: the order and content of the
/// writes.
void main() {
  late UserRepository users;
  late BodyRepository body;
  late RecordingAnalytics analytics;
  late List<String> calls;
  final now = DateTime.utc(2026, 10, 15, 9);
  final profile = UserModel(
    userId: 'uid',
    submittedWeightKilograms: 80,
    submittedHeightCentimeters: 180,
    submittedGender: Gender.male,
    submittedDailyActivityLevel: ActivityLevel.moderate,
    submittedDateOfBirth: DateTime(1996),
  );
  WeightGoal replaced(GoalStatus status) => WeightGoal(
    goalId: 'uid',
    userId: 'uid',
    objective: OverarchingObjective.gainWeight,
    startingWeightKg: 70,
    targetWeightKg: 75,
    weeklyChangeKg: 0.2,
    createdAt: DateTime.utc(2025),
    status: status,
  );

  setUpAll(() {
    registerFallbackValue(<UserFieldValue>[]);
    registerFallbackValue(replaced(GoalStatus.active));
  });

  setUp(() {
    users = MockUserRepository();
    body = MockBodyRepository();
    analytics = RecordingAnalytics();
    calls = [];
    when(() => users.updateUserFields(any(), any()))
        .thenAnswer((_) async => calls.add('updateUserFields'));
    when(() => body.saveGoal(any()))
        .thenAnswer((_) async => calls.add('saveGoal'));
    when(() => body.abandonGoal(any(), any())).thenAnswer(
      (invocation) async =>
          calls.add('abandonGoal ${invocation.positionalArguments.last}'),
    );
    when(() => body.watchMeasurements('uid'))
        .thenAnswer((_) => Stream.value(const []));
    when(
      () => body.watchCurrentGoal(
        'uid',
        currentGoalId: any(named: 'currentGoalId'),
      ),
    ).thenAnswer((_) => Stream.value(null));
  });

  GoalSetupCubit build({UserModel? user}) => GoalSetupCubit(
    userRepository: users,
    bodyRepository: body,
    analyticsRepository: analytics.repository,
    profile: user ?? profile,
    now: () => now,
    newId: () => 'GOAL-1',
  );

  group('load', () {
    test('reads the latest weigh-in, else the onboarding weight', () async {
      final cubit = build();
      await cubit.load();
      expect(cubit.state.status, GoalSetupStatus.ready);
      expect(cubit.state.currentKg, 80);
      expect(cubit.state.floorKcal, 1500);
      expect(cubit.state.expenditureKcal, greaterThan(2000));

      when(() => body.watchMeasurements('uid')).thenAnswer(
        (_) => Stream.value([
          for (final (day, weight) in [(3, 79.0), (5, 78.4), (4, 81.0)])
            BodyMeasurementEntry(
              id: 'w$day',
              authorId: 'uid',
              weightKg: weight,
              date: DateTime.utc(2026, 10, day),
              source: WeightSource.manual,
              dateCreated: DateTime.utc(2026, 10, day),
            ),
          BodyMeasurementEntry(
            id: 'fat',
            authorId: 'uid',
            bodyFatPercentage: 20,
            date: DateTime.utc(2026, 10, 9),
            source: WeightSource.manual,
            dateCreated: DateTime.utc(2026, 10, 9),
          ),
        ]),
      );
      final latest = build();
      await latest.load();
      expect(latest.state.currentKg, 78.4);
    });

    test('a failed read leaves the onboarding weight', () async {
      when(() => body.watchMeasurements('uid'))
          .thenAnswer((_) => Stream.error(Exception('read')));
      final cubit = build();
      await cubit.load();
      expect(cubit.state.currentKg, 80);
    });
  });

  group('objective', () {
    test('needs an objective and a current weight', () async {
      final cubit = build(user: const UserModel(userId: 'uid'));
      await cubit.load();
      expect(cubit.state.canContinueObjective, isFalse);
      cubit
        ..objectiveSelected(OverarchingObjective.loseWeight)
        ..objectiveContinued();
      expect(cubit.state.question, GoalQuestion.objective);
    });

    test('maintaining skips to the summary at the current weight', () async {
      final cubit = build();
      await cubit.load();
      cubit
        ..objectiveSelected(OverarchingObjective.maintain)
        ..objectiveContinued();
      expect(cubit.state.question, GoalQuestion.summary);
      expect((cubit.state.targetKg, cubit.state.rateKg), (80.0, 0.0));
      expect(cubit.back(), isTrue);
      expect(cubit.state.question, GoalQuestion.objective);
      expect(cubit.back(), isFalse);
    });

    test('losing picks a target, then a rate', () async {
      final cubit = build();
      await cubit.load();
      cubit
        ..objectiveSelected(OverarchingObjective.loseWeight)
        ..objectiveContinued();
      expect(cubit.state.question, GoalQuestion.targetWeight);
      // Opens on today's weight, which isn't a target to lose towards.
      expect(cubit.state.targetWheel, 80);
      expect(cubit.state.canContinueTarget, isFalse);
      cubit
        ..targetContinued()
        ..targetWheelChanged(70)
        ..targetContinued();
      expect(cubit.state.question, GoalQuestion.rate);
      expect(cubit.state.rateKg, closeTo(0.4, 1e-9));
      cubit.rateChanged(0.53);
      expect(cubit.state.rateKg, closeTo(0.55, 1e-9));
      cubit.rateContinued();
      expect(cubit.state.question, GoalQuestion.summary);
      expect(cubit.back(), isTrue);
      expect(cubit.state.question, GoalQuestion.rate);
      expect(cubit.back(), isTrue);
      expect(cubit.state.question, GoalQuestion.targetWeight);
      expect(
        analytics.events
            .where((e) => e.type == LogType.info)
            .map((e) => e.eventName),
        [
          'OverarchingObjecting_Navigate',
          'Onboarding_TargetWeight_Navigate',
          'Onboarding_WeightRate_Navigate',
        ],
      );
      expect(analytics.last('TargetWeightView_Appear').parameters, {
        'is_onboarding': true,
      });
    });

    test('a pounds wheel saves the target in kilograms', () async {
      final cubit = build(
        user: const UserModel(
          userId: 'uid',
          submittedWeightKilograms: 80,
          submittedWeightUnitPreference: WeightUnitPreference.pounds,
        ),
      );
      await cubit.load();
      cubit
        ..objectiveSelected(OverarchingObjective.gainWeight)
        ..objectiveContinued();
      expect(cubit.state.targetWheel, 177);
      cubit.targetWheelChanged(200);
      expect(cubit.state.targetKg, closeTo(200 / 2.20462, 1e-9));
    });

    test('a rate needs a rate', () {
      final cubit = build()
        ..rateChanged(1)
        ..rateContinued()
        ..targetContinued();
      expect(cubit.state.question, GoalQuestion.objective);
    });
  });

  group('save', () {
    Future<GoalSetupCubit> atSummary({double target = 70}) async {
      final cubit = build();
      await cubit.load();
      cubit
        ..objectiveSelected(OverarchingObjective.loseWeight)
        ..objectiveContinued()
        ..targetWheelChanged(target.toInt())
        ..targetContinued()
        ..rateContinued();
      return cubit;
    }

    test('saves the goal, abandons the active one it replaces, then points '
        'the profile at it', () async {
      when(
        () => body.watchCurrentGoal(
          'uid',
          currentGoalId: any(named: 'currentGoalId'),
        ),
      ).thenAnswer((_) => Stream.value(replaced(GoalStatus.active)));
      final cubit = await atSummary();
      await cubit.save();

      expect(calls, ['saveGoal', 'abandonGoal uid', 'updateUserFields']);

      final saved =
          verify(() => body.saveGoal(captureAny())).captured.single
              as WeightGoal;
      expect(saved.toFirestore(), {
        WeightGoalKeys.goalId: 'GOAL-1',
        WeightGoalKeys.userId: 'uid',
        WeightGoalKeys.objective: {'loseWeight': <String, Object?>{}},
        WeightGoalKeys.startingWeightKg: 80.0,
        WeightGoalKeys.targetWeightKg: 70.0,
        WeightGoalKeys.weeklyChangeKg: closeTo(0.4, 1e-9),
        WeightGoalKeys.createdAt: now,
        WeightGoalKeys.status: 'active',
      });
      final fields = verify(() => users.updateUserFields('uid', captureAny()))
          .captured;
      expect(fieldsOf(fields.single), {
        UserModelKeys.submittedCurrentGoalId: 'GOAL-1',
      });
      expect(cubit.state.status, GoalSetupStatus.saved);
      expect(analytics.names.sublist(analytics.names.length - 3), [
        'Onboarding_Goal_Save_Start',
        'Onboarding_Goal_Save_Success',
        'Onboarding_Goal_Navigation',
      ]);
    });

    test('a failed abandon is passed over, as Swift ignores it', () async {
      when(
        () => body.watchCurrentGoal(
          'uid',
          currentGoalId: any(named: 'currentGoalId'),
        ),
      ).thenAnswer((_) => Stream.value(replaced(GoalStatus.active)));
      when(() => body.abandonGoal(any(), any())).thenThrow(Exception('rule'));
      final cubit = await atSummary();
      await cubit.save();
      verify(() => users.updateUserFields('uid', any())).called(1);
      expect(cubit.state.status, GoalSetupStatus.saved);
    });

    test('a goal that is not active is left alone', () async {
      when(
        () => body.watchCurrentGoal(
          'uid',
          currentGoalId: any(named: 'currentGoalId'),
        ),
      ).thenAnswer((_) => Stream.value(replaced(GoalStatus.completed)));
      final cubit = await atSummary();
      await cubit.save();
      verifyNever(() => body.abandonGoal(any(), any()));
    });

    test('a failed save stops before the profile, and says so', () async {
      when(() => body.saveGoal(any())).thenThrow(Exception('offline'));
      final cubit = await atSummary();
      await cubit.save();
      verifyNever(() => users.updateUserFields(any(), any()));
      expect(cubit.state.status, GoalSetupStatus.failure);
      expect(analytics.last('Onboarding_Goal_Save_Fail').type, LogType.severe);
    });

    test('without a current weight nothing is saved', () async {
      final cubit = build(user: const UserModel(userId: 'uid'));
      await cubit.load();
      cubit.objectiveSelected(OverarchingObjective.maintain);
      await cubit.save();
      verifyNever(() => body.saveGoal(any()));
      expect(cubit.state.status, GoalSetupStatus.failure);
    });

    test('saves once, however often it is pressed', () async {
      final cubit = await atSummary();
      await Future.wait([cubit.save(), cubit.save()]);
      await cubit.save();
      verify(() => body.saveGoal(any())).called(1);
      final none = build();
      await none.save();
      verifyNever(() => body.saveGoal(any()));
    });
  });

  test('ranges follow the unit and the objective', () async {
    final cubit = build();
    expect(cubit.state.targetRange, isNull);
    expect(cubit.state.rateRules, isNull);
    await cubit.load();
    cubit.objectiveSelected(OverarchingObjective.gainWeight);
    expect(cubit.state.targetRange, (min: 80, max: 200));
    unawaited(cubit.close());
  });
}
