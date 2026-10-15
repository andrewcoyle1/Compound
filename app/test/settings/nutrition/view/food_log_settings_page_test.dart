import 'package:app_ui/app_ui.dart';
import 'package:compound/settings/nutrition/logic/nutrition_settings_labels.dart';
import 'package:compound/settings/nutrition/view/favourite_measurements_page.dart';
import 'package:compound/settings/nutrition/view/food_log_settings_page.dart';
import 'package:compound/settings/nutrition/view/logger_banner_page.dart';
import 'package:compound/settings/nutrition/view/logger_food_tiles_page.dart';
import 'package:compound/settings/nutrition/view/timeline_food_tiles_page.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/helpers.dart';
import '../helpers.dart';

void main() {
  late SpyNutritionRepository repository;

  setUp(() => repository = SpyNutritionRepository());

  GoRoute route(String path, String name, Widget page) =>
      GoRoute(path: path, name: name, builder: (_, _) => page);

  Future<void> pump(WidgetTester tester, {String at = '/food-log'}) async {
    useTallView(tester);
    await tester.pumpApp(
      const SizedBox(),
      appBloc: signedInAppBloc(),
      nutritionRepository: repository,
      router: GoRouter(
        initialLocation: at,
        routes: [
          GoRoute(
            path: '/food-log',
            name: FoodLogSettingsPage.name,
            builder: (_, _) => const FoodLogSettingsPage(),
            routes: [
              route(
                LoggerBannerPage.path,
                LoggerBannerPage.name,
                const LoggerBannerPage(),
              ),
              route(
                LoggerFoodTilesPage.path,
                LoggerFoodTilesPage.name,
                const LoggerFoodTilesPage(),
              ),
              route(
                TimelineFoodTilesPage.path,
                TimelineFoodTilesPage.name,
                const TimelineFoodTilesPage(),
              ),
              route(
                FavouriteMeasurementsPage.path,
                FavouriteMeasurementsPage.name,
                const FavouriteMeasurementsPage(),
              ),
            ],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  group(FoodLogSettingsPage, () {
    testWidgets('shows every section of the stored settings', (tester) async {
      await pump(tester);
      for (final text in [
        'Nutrient Reporting',
        'Timeline Options',
        'Food Search',
        'Food Tiles',
        'Logger Options',
        hourLabel(7, 'en'),
        hourLabel(23, 'en'),
        'Left',
        'No negative numbers will be used if you exceed a nutrient target.',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('a switch saves as it is flicked, and its subtitle follows', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Show Overages'));
      await tester.pumpAndSettle();

      expect(repository.saved.single.showOverages, isTrue);
      expect(
        find.text(
          'Negative numbers will be used in nutrient remaining views if you '
          'exceed your target.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an hour is chosen from the list', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Start Hour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(hourLabel(5, 'en')));
      await tester.pumpAndSettle();

      expect(repository.saved.single.startHour, 5);
      expect(find.text(hourLabel(5, 'en')), findsOneWidget);
    });

    testWidgets('choosing the side already chosen saves nothing', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Timestamp Side'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Left').last);
      await tester.pumpAndSettle();
      expect(repository.saved, isEmpty);

      await tester.tap(find.text('Timestamp Side'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Right'));
      await tester.pumpAndSettle();
      expect(repository.saved.single.timestampSide, TimestampSide.right);
    });

    for (final (row, page) in [
      ('Timeline Food Tiles', TimelineFoodTilesPage),
      ('Logger Food Tiles', LoggerFoodTilesPage),
      ('Logger Banner', LoggerBannerPage),
      ('Favorite Measurements', FavouriteMeasurementsPage),
    ]) {
      testWidgets('$row opens its screen', (tester) async {
        await pump(tester);
        await tester.tap(find.text(row));
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget);
      });
    }

    testWidgets('a failed save says so', (tester) async {
      await pump(tester);
      repository.failing = true;
      await tester.tap(find.text('Quick Add'));
      await tester.pump();
      expect(find.text('Unable to Save Settings'), findsOneWidget);
    });
  });

  group('Food Log sub-screens', () {
    for (final (path, switches) in [
      (
        'banner',
        {
          'Calories Ring': FoodLogSettingsKeys.showCaloriesRing,
          'Protein Ring': FoodLogSettingsKeys.showProteinRing,
          'Fat Ring': FoodLogSettingsKeys.showFatRing,
          'Carbs Ring': FoodLogSettingsKeys.showCarbsRing,
        },
      ),
      (
        'logger-tiles',
        {
          'Show Food Image': FoodLogSettingsKeys.showFoodImageInLogger,
          'Show Calories': FoodLogSettingsKeys.showCaloriesInLogger,
          'Show Macros': FoodLogSettingsKeys.showMacrosInLogger,
          'Show Portion': FoodLogSettingsKeys.showPortionInLogger,
        },
      ),
      (
        'timeline-tiles',
        {
          'Show Food Image': FoodLogSettingsKeys.showFoodImageInTimeline,
          'Show Calories': FoodLogSettingsKeys.showCaloriesInTimeline,
          'Show Macros': FoodLogSettingsKeys.showMacrosInTimeline,
        },
      ),
    ]) {
      testWidgets('$path: each switch writes its own field', (tester) async {
        await pump(tester, at: '/food-log/$path');
        for (final title in switches.keys) {
          await tester.tap(find.text(title));
          await tester.pumpAndSettle();
        }
        expect(repository.saved.last.toFirestore(), {
          ...const FoodLogSettings(authorId: uid).toFirestore(),
          for (final key in switches.values) key: false,
        });
      });
    }

    testWidgets('favorite measurements pin and unpin a unit', (tester) async {
      await pump(tester, at: '/food-log/favourite-measurements');
      expect(find.byType(AppSelectableRow), findsNWidgets(9));

      await tester.tap(find.text('kJ'));
      await tester.pumpAndSettle();
      expect(repository.saved.last.favouriteMeasurements, contains('kJ'));

      await tester.tap(find.text('kJ'));
      await tester.pumpAndSettle();
      expect(
        repository.saved.last.favouriteMeasurements,
        isNot(contains('kJ')),
      );
    });
  });
}
