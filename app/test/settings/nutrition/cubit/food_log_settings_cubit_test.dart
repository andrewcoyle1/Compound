import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/settings/nutrition/cubit/food_log_settings_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  late SpyNutritionRepository repository;
  late RecordingAnalytics analytics;

  FoodLogSettingsCubit build({String screen = 'FoodLogSettingsView'}) =>
      FoodLogSettingsCubit(
        nutritionRepository: repository,
        analytics: analytics,
        uid: uid,
        screen: screen,
      );

  /// The settings with [fields] changed, as stored.
  Map<String, Object?> stored(
    FoodLogSettings base,
    Map<String, Object?> fields,
  ) => {...base.toFirestore(), ...fields};

  setUp(() {
    repository = SpyNutritionRepository();
    analytics = RecordingAnalytics();
  });

  group(FoodLogSettingsCubit, () {
    test('reads the stored settings, or the defaults', () async {
      final cubit = build();
      await pumpEventQueue();
      expect(
        cubit.state.settings!.toFirestore(),
        const FoodLogSettings(authorId: uid).toFirestore(),
      );
      await cubit.close();
    });

    test('does nothing before the first read', () async {
      final cubit = build();
      await cubit.set(FoodLogSettingsKeys.premove, true);
      expect(repository.saved, isEmpty);
      await cubit.close();
    });

    test('each toggle is saved as it is flicked', () async {
      final cubit = build();
      await pumpEventQueue();

      await cubit.set(FoodLogSettingsKeys.showsFoodTimestamps, false);

      expect(
        repository.saved.single.toFirestore(),
        stored(const FoodLogSettings(authorId: uid), {
          FoodLogSettingsKeys.showsFoodTimestamps: false,
        }),
      );
      expect(cubit.state.settings!.showsFoodTimestamps, isFalse);
      await cubit.close();
    });

    test('one toggle does not undo another', () async {
      final cubit = build();
      await pumpEventQueue();

      await Future.wait([
        cubit.set(FoodLogSettingsKeys.showsFoodTimestamps, false),
        cubit.set(FoodLogSettingsKeys.showHourlyMacroTotals, false),
        cubit.set(FoodLogSettingsKeys.showCalendarWeekBanner, false),
        cubit.set(FoodLogSettingsKeys.showAddFoodsButton, false),
      ]);

      expect(repository.saved, hasLength(4));
      expect(
        repository.saved.last.toFirestore(),
        stored(const FoodLogSettings(authorId: uid), {
          FoodLogSettingsKeys.showsFoodTimestamps: false,
          FoodLogSettingsKeys.showHourlyMacroTotals: false,
          FoodLogSettingsKeys.showCalendarWeekBanner: false,
          FoodLogSettingsKeys.showAddFoodsButton: false,
        }),
      );
      await cubit.close();
    });

    test('saving a toggle keeps the favourites in the document', () async {
      repository = SpyNutritionRepository(
        foodLogSettings: const FoodLogSettings(
          authorId: uid,
          favouriteFoodIds: ['food-1', 'food-2'],
          favouriteRecipeIds: ['recipe-1'],
        ),
      );
      final cubit = build();
      await pumpEventQueue();

      await cubit.set(FoodLogSettingsKeys.showOverages, true);

      expect(repository.saved.single.favouriteFoodIds, ['food-1', 'food-2']);
      expect(repository.saved.single.favouriteRecipeIds, ['recipe-1']);
      expect(repository.saved.single.showOverages, isTrue);
      await cubit.close();
    });

    test('returning from a sub-screen does not undo its changes', () async {
      final foodLog = build();
      await pumpEventQueue();
      final tiles = build(screen: 'TimelineFoodTilesView');
      await pumpEventQueue();
      await tiles.set(FoodLogSettingsKeys.showCaloriesInTimeline, false);
      await tiles.set(FoodLogSettingsKeys.showCaloriesRing, false);
      await tiles.close();

      await foodLog.set(FoodLogSettingsKeys.showsFoodTimestamps, false);

      expect(
        repository.saved.last.toFirestore(),
        stored(const FoodLogSettings(authorId: uid), {
          FoodLogSettingsKeys.showCaloriesInTimeline: false,
          FoodLogSettingsKeys.showCaloriesRing: false,
          FoodLogSettingsKeys.showsFoodTimestamps: false,
        }),
      );
      await foodLog.close();
    });

    test('a change from the nutrition tab is carried, not undone', () async {
      final cubit = build();
      await pumpEventQueue();
      await repository.saveFoodLogSettings(
        const FoodLogSettings(authorId: uid, favouriteFoodIds: ['food-9']),
      );
      await pumpEventQueue();

      await cubit.set(FoodLogSettingsKeys.premove, true);

      expect(repository.saved.last.favouriteFoodIds, ['food-9']);
      await cubit.close();
    });

    test('the logger switches are saved both ways', () async {
      repository = SpyNutritionRepository(
        foodLogSettings: const FoodLogSettings(
          authorId: uid,
          favouriteFoodIds: ['food-1'],
        ),
      );
      final cubit = build();
      await pumpEventQueue();

      await cubit.set(FoodLogSettingsKeys.autoSetCurrentTime, true);
      await cubit.set(FoodLogSettingsKeys.quickAddEnabled, true);
      expect(repository.saved.last.autoSetCurrentTime, isTrue);
      expect(repository.saved.last.quickAddEnabled, isTrue);

      await cubit.set(FoodLogSettingsKeys.autoSetCurrentTime, false);
      expect(repository.saved.last.autoSetCurrentTime, isFalse);
      expect(repository.saved.last.quickAddEnabled, isTrue);

      await cubit.set(FoodLogSettingsKeys.quickAddEnabled, false);
      expect(repository.saved.last.quickAddEnabled, isFalse);
      expect(repository.saved.last.favouriteFoodIds, ['food-1']);
      await cubit.close();
    });

    test('both ends of the hour range are saved', () async {
      final cubit = build();
      await pumpEventQueue();

      await cubit.set(FoodLogSettingsKeys.startHour, 5);
      await cubit.set(FoodLogSettingsKeys.endHour, 21);

      expect(
        repository.saved.last.toFirestore(),
        stored(const FoodLogSettings(authorId: uid), {
          FoodLogSettingsKeys.startHour: 5,
          FoodLogSettingsKeys.endHour: 21,
        }),
      );
      await cubit.close();
    });

    test('the timestamp side is saved as its raw value', () async {
      final cubit = build();
      await pumpEventQueue();

      await cubit.set(FoodLogSettingsKeys.timestampSide, TimestampSide.right);

      expect(repository.saved.single.timestampSide, TimestampSide.right);
      expect(
        repository.saved.single
            .toFirestore()[FoodLogSettingsKeys.timestampSide],
        'right',
      );
      await cubit.close();
    });

    test('the two food source filters are independent', () async {
      final cubit = build();
      await pumpEventQueue();

      await cubit.set(FoodLogSettingsKeys.showBrandedFoods, false);
      await cubit.set(FoodLogSettingsKeys.showOpenFoodFactsFoods, false);

      expect(repository.saved.last.showBrandedFoods, isFalse);
      expect(repository.saved.last.showOpenFoodFactsFoods, isFalse);
      await cubit.close();
    });

    test(
      'a measurement is pinned at the end and unpinned where it is',
      () async {
        final cubit = build();
        await pumpEventQueue();

        await cubit.toggleMeasurement('kJ');
        expect(repository.saved.last.favouriteMeasurements, [
          ...const FoodLogSettings(authorId: uid).favouriteMeasurements,
          'kJ',
        ]);

        await cubit.toggleMeasurement('g');
        expect(repository.saved.last.favouriteMeasurements, [
          for (final unit in const FoodLogSettings(
            authorId: uid,
          ).favouriteMeasurements)
            if (unit != 'g') unit,
          'kJ',
        ]);
        await cubit.close();
      },
    );

    test("offers Swift's measurements", () {
      expect(FoodLogSettingsCubit.measurements, [
        'g',
        'oz',
        'ml',
        'cup',
        'tbsp',
        'tsp',
        'serving',
        'kcal',
        'kJ',
      ]);
    });

    test('tracks the screen and its saves under the Swift names', () async {
      final cubit = build(screen: 'LoggerBannerView');
      await pumpEventQueue();
      await cubit.set(FoodLogSettingsKeys.showFatRing, false);
      await cubit.close();

      expect(analytics.events, [
        ('LoggerBannerView_Appear', LogType.analytic),
        ('LoggerBannerView_Save_Start', LogType.analytic),
        ('LoggerBannerView_Save_Success', LogType.analytic),
        ('LoggerBannerView_Disappear', LogType.analytic),
      ]);
    });

    test('a failed save is tracked and counted', () async {
      final cubit = build();
      await pumpEventQueue();
      repository.failing = true;

      await cubit.set(FoodLogSettingsKeys.premove, true);

      expect(cubit.state.saveFailures, 1);
      expect(analytics.events.last, (
        'FoodLogSettingsView_Save_Fail',
        LogType.severe,
      ));
      await cubit.close();
    });

    test('keeps what it has when the document stream fails', () async {
      final cubit = FoodLogSettingsCubit(
        nutritionRepository: _FailingNutritionRepository(),
        analytics: analytics,
        uid: uid,
        screen: 'FoodLogSettingsView',
      );
      await pumpEventQueue();
      expect(cubit.state.settings, isNull);
      await cubit.close();
    });
  });
}

class _FailingNutritionRepository extends SpyNutritionRepository {
  @override
  Stream<FoodLogSettings> watchFoodLogSettings(String uid) =>
      Stream.error(StateError('offline'));
}
