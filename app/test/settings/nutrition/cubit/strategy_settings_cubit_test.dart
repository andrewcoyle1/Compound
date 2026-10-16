import 'package:compound/settings/nutrition/cubit/strategy_settings_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late SpyCheckInRepository repository;
  late RecordingAnalytics analytics;

  StrategySettingsCubit build({String screen = 'StrategySettingsView'}) =>
      StrategySettingsCubit(
        checkInRepository: repository,
        analytics: analytics,
        uid: uid,
        screen: screen,
      );

  setUp(() {
    repository = SpyCheckInRepository();
    analytics = RecordingAnalytics();
  });

  group('StrategySettingsCubit on Strategy', () {
    test('one toggle does not undo another', () async {
      final cubit = build();
      await pumpEventQueue();

      await cubit.set(NutritionStrategySettingsKeys.fastCheckIn, true);
      await cubit.set(
        NutritionStrategySettingsKeys.partialLoggingEnabled,
        false,
      );
      await cubit.set(NutritionStrategySettingsKeys.weighInEnabled, false);
      await cubit.set(NutritionStrategySettingsKeys.fastingEnabled, false);
      await cubit.set(NutritionStrategySettingsKeys.loggingBreakEnabled, false);

      expect(repository.saved, hasLength(5));
      expect(
        repository.saved.last.toFirestore(),
        const NutritionStrategySettings(
          authorId: uid,
          fastCheckIn: true,
          partialLoggingEnabled: false,
          weighInEnabled: false,
          fastingEnabled: false,
          loggingBreakEnabled: false,
        ).toFirestore(),
      );
      await cubit.close();
    });

    test('saving a toggle keeps the expenditure choices', () async {
      repository = SpyCheckInRepository(
        settings: const [
          NutritionStrategySettings(
            authorId: uid,
            bmrEquation: BmrEquation.harrisBenedict,
            calculationMode: ExpenditureCalculationMode.fixed,
          ),
        ],
      );
      final cubit = build();
      await pumpEventQueue();

      await cubit.set(NutritionStrategySettingsKeys.weighInEnabled, false);

      expect(repository.saved.single.bmrEquation, BmrEquation.harrisBenedict);
      expect(
        repository.saved.single.calculationMode,
        ExpenditureCalculationMode.fixed,
      );
      await cubit.close();
    });

    test('saves the check-in weekday as picked', () async {
      final cubit = build();
      await pumpEventQueue();
      for (var weekday = 1; weekday <= 7; weekday++) {
        await cubit.set(NutritionStrategySettingsKeys.checkInWeekday, weekday);
        expect(repository.saved.last.checkInWeekday, weekday);
      }
      expect(repository.saved, hasLength(7));
      await cubit.close();
    });

    test('tracks the screen under the Swift name', () async {
      final cubit = build();
      await pumpEventQueue();
      await cubit.close();
      expect(analytics.names, [
        'StrategySettingsView_Appear',
        'StrategySettingsView_Disappear',
      ]);
    });
  });

  group('StrategySettingsCubit on Expenditure', () {
    final chosen = DateTime.utc(2023, 11, 14, 22, 13, 20);

    test('the BMR equation is saved as its raw value', () async {
      final cubit = build(screen: 'ExpenditureSettingsView');
      await pumpEventQueue();

      await cubit.set(
        NutritionStrategySettingsKeys.bmrEquation,
        BmrEquation.cunningham,
      );

      expect(repository.saved.single.bmrEquation, BmrEquation.cunningham);
      expect(
        repository.saved.single
            .toFirestore()[NutritionStrategySettingsKeys.bmrEquation],
        'katchMcArdle',
      );
      expect(cubit.state.settings!.bmrEquation, BmrEquation.cunningham);
      await cubit.close();
    });

    test('saving one choice keeps the others', () async {
      repository = SpyCheckInRepository(
        settings: const [
          NutritionStrategySettings(
            authorId: uid,
            checkInWeekday: 6,
            fastingEnabled: false,
          ),
        ],
      );
      final cubit = build(screen: 'ExpenditureSettingsView');
      await pumpEventQueue();

      await cubit.set(
        NutritionStrategySettingsKeys.estimationMethod,
        ExpenditureEstimationMethod.bodyFatAware,
      );
      await cubit.set(
        NutritionStrategySettingsKeys.calculationMode,
        ExpenditureCalculationMode.fixed,
      );
      await cubit.set(NutritionStrategySettingsKeys.stepInformedUpdates, true);

      expect(
        repository.saved.last.toFirestore(),
        const NutritionStrategySettings(
          authorId: uid,
          checkInWeekday: 6,
          fastingEnabled: false,
          estimationMethod: ExpenditureEstimationMethod.bodyFatAware,
          calculationMode: ExpenditureCalculationMode.fixed,
          stepInformedUpdates: true,
        ).toFirestore(),
      );
      expect(repository.saved.last.predictiveGoalAdjustments, isTrue);
      await cubit.close();
    });

    test('a chosen start date is saved', () async {
      final cubit = build(screen: 'ExpenditureSettingsView');
      await pumpEventQueue();

      await cubit.set(
        NutritionStrategySettingsKeys.calculationStartDate,
        chosen,
      );

      expect(repository.saved.single.calculationStartDate, chosen);
      expect(cubit.state.settings!.calculationStartDate, chosen);
      await cubit.close();
    });

    test('clearing the start date saves the cleared value', () async {
      repository = SpyCheckInRepository(
        settings: [
          NutritionStrategySettings(
            authorId: uid,
            calculationStartDate: chosen,
          ),
        ],
      );
      final cubit = build(screen: 'ExpenditureSettingsView');
      await pumpEventQueue();

      await cubit.set(NutritionStrategySettingsKeys.calculationStartDate, null);

      expect(repository.saved.single.calculationStartDate, isNull);
      expect(
        repository.saved.single.toFirestore(),
        isNot(contains(NutritionStrategySettingsKeys.calculationStartDate)),
      );
      expect(
        (await repository.watchStrategySettings(uid).first)
            .calculationStartDate,
        isNull,
      );
      await cubit.close();
    });
  });
}
