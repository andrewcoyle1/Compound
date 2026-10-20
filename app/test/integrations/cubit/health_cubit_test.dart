import 'package:analytics_repository/analytics_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/integrations/integrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_repository/health_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../helpers/analytics_recorder.dart';

const _uid = 'user-1';

/// Ported from Swift's Steps, Today and Nutrition presenters: each screen
/// asks for its own access where Swift asks, then imports.
void main() {
  late FakeHealthPlatform platform;
  late InMemoryBodyRepository body;
  late InMemoryNutritionRepository nutrition;
  late AnalyticsRecorder analytics;
  late HealthCubit cubit;

  setUp(() {
    platform = sampleHealthPlatform(DateTime.now());
    body = InMemoryBodyRepository();
    nutrition = InMemoryNutritionRepository();
    analytics = AnalyticsRecorder();
    cubit = HealthCubit(
      health: HealthRepository(
        platform: platform,
        body: body,
        nutrition: nutrition,
      ),
      analytics: analytics,
    );
  });

  tearDown(() => cubit.close());

  group(HealthCubit, () {
    test('signing in imports steps, weigh-ins and food', () async {
      cubit.userChanged(_uid);
      await pumpEventQueue();

      expect(await body.watchSteps(_uid).first, isNotEmpty);
      expect(await body.watchMeasurements(_uid).first, hasLength(7));
      expect(
        await nutrition
            .watchMeals(_uid, includeHiddenHealthImports: true)
            .first,
        hasLength(2),
      );
      // Nothing asked for at sign-in: the screens ask when they appear.
      expect(platform.requested, isEmpty);
    });

    test('nothing runs signed out, or twice for the same account', () async {
      await cubit.importSteps();
      await cubit.stepsAppeared();
      await cubit.syncBody();
      await cubit.nutritionAppeared();
      expect(platform.requested, isEmpty);

      cubit
        ..userChanged(_uid)
        ..userChanged(_uid);
      expect(cubit.state, const HealthState(uid: _uid));
      cubit.userChanged(null);
      expect(cubit.state, const HealthState());
    });

    test('the Steps screen asks for step access, then imports', () async {
      cubit.userChanged(_uid);
      await cubit.stepsAppeared();
      expect(platform.requested, [HealthScope.steps]);
      expect(analytics.names, isEmpty);
    });

    test('a refusal on appearing is noted and still imports', () async {
      platform.granted = false;
      cubit.userChanged(_uid);
      await pumpEventQueue();
      await body.watchSteps(_uid).first;

      await cubit.stepsAppeared();

      final event = analytics.events.single;
      expect(event.eventName, 'StepsView_LoadAuthorisation_Fail');
      expect(event.type, LogType.warning);
      expect(cubit.state.stepsAccessFailures, 0);
    });

    test('syncing steps is tracked from start to success', () async {
      cubit.userChanged(_uid);
      await cubit.stepsSyncPressed();
      expect(analytics.names, [
        'StepsView_Sync_Start',
        'StepsView_Sync_Success',
      ]);
      expect(cubit.state.stepsAccessFailures, 0);
    });

    test('a refused sync says so and stops', () async {
      platform.granted = false;
      cubit.userChanged(_uid);

      await cubit.stepsSyncPressed();

      expect(analytics.names, ['StepsView_Sync_Start', 'StepsView_Sync_Fail']);
      expect(analytics.events.last.type, LogType.severe);
      expect(cubit.state.stepsAccessFailures, 1);
    });

    test("Today's connect asks for steps and says when refused", () async {
      cubit.userChanged(_uid);
      await cubit.connectPressed();
      expect(platform.requested, [HealthScope.steps]);
      expect(analytics.names, isEmpty);

      platform.granted = false;
      await cubit.connectPressed();
      expect(analytics.names, ['TodayView_ConnectHealth_Fail']);
      expect(analytics.events.last.type, LogType.warning);
      expect(cubit.state.stepsAccessFailures, 1);
    });

    test('without Health there is nothing to ask, or to refuse', () async {
      platform.available = false;
      cubit.userChanged(_uid);

      await cubit.stepsSyncPressed();
      await cubit.nutritionAppeared();

      expect(platform.requested, isEmpty);
      expect(cubit.state.stepsAccessFailures, 0);
      expect(analytics.names, [
        'StepsView_Sync_Start',
        'StepsView_Sync_Success',
      ]);
    });

    test('the body screens ask for weight access, then import', () async {
      cubit.userChanged(_uid);
      await cubit.syncBody();
      // The sign-in import was still running: this run follows it.
      await pumpEventQueue();
      expect(platform.requested, [HealthScope.bodyMeasurements]);
      expect(await body.watchMeasurements(_uid).first, hasLength(7));
    });

    test('Nutrition asks for food access and notes a refusal', () async {
      cubit.userChanged(_uid);
      await cubit.nutritionAppeared();
      expect(platform.requested, [HealthScope.nutrition]);
      expect(analytics.names, isEmpty);

      platform.granted = false;
      await cubit.nutritionAppeared();
      expect(analytics.names, ['NutritionView_HealthAuthorisation_Fail']);
      expect(analytics.events.last.type, LogType.warning);
    });
  });
}
