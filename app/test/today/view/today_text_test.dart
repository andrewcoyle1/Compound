import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/today/logic/today_checklist.dart';
import 'package:compound/today/view/today_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Mirrors the wording checks of the Swift `TodayChecklistTests`.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const kg = AppWeightUnit.kilograms;
  const locale = 'en';

  String detail(ChecklistItem item) =>
      TodayText.detail(l10n, item, kg, locale: locale);

  test('the nutrition detail reads calories and protein against target', () {
    expect(
      detail(
        const NutritionItem(
          calories: 1450,
          proteinGrams: 110,
          mealsLogged: 2,
          calorieTarget: 2000,
          proteinTarget: 150,
        ),
      ),
      '1,450 / 2,000 kcal · 110 g / 150 g protein',
    );
    expect(
      detail(
        const NutritionItem(
          calories: 1450,
          proteinGrams: 110,
          mealsLogged: 2,
          calorieTarget: 2000,
        ),
      ),
      '1,450 / 2,000 kcal',
    );
    expect(
      detail(
        const NutritionItem(calories: 600, proteinGrams: 0, mealsLogged: 1),
      ),
      '600 kcal logged',
    );
    expect(
      detail(const NutritionItem(calories: 0, proteinGrams: 0, mealsLogged: 0)),
      'Nothing logged yet',
    );
  });

  test("the weigh-in shows the week's change and the goal pace", () {
    expect(
      detail(
        const WeighInItem(
          isToday: true,
          latestKg: 82.4,
          weekChangeKg: -0.4,
          goalWeeklyChangeKg: -0.5,
        ),
      ),
      '82.4 kg · −0.4 kg this week · goal −0.5 kg/wk',
    );
    expect(
      detail(
        const WeighInItem(isToday: true, latestKg: 82.4, goalWeeklyChangeKg: 0),
      ),
      '82.4 kg',
    );
    expect(detail(const WeighInItem(isToday: false)), 'No weigh-ins yet');
  });

  test('steps and training details', () {
    expect(
      detail(const StepsItem(today: 6000, goal: 8000)),
      '6,000 / 8,000 steps',
    );
    expect(detail(TrainingItem(fixtureSession('a'))), 'Session a');
  });

  test('signed weights', () {
    expect(TodayText.signedWeight(0.3, kg, locale: locale), '+0.3 kg');
    expect(TodayText.signedWeight(-0.4, kg, locale: locale), '−0.4 kg');
    expect(TodayText.signedWeight(0, kg, locale: locale), '0 kg');
  });

  test('every item and starter step has a title and a glyph', () {
    final items = <ChecklistItem>[
      TrainingItem(fixtureSession('a')),
      const NutritionItem(calories: 0, proteinGrams: 0, mealsLogged: 0),
      const WeighInItem(isToday: false),
      const StepsItem(today: 0, goal: 1),
    ];
    expect(items.map((item) => TodayText.title(l10n, item)), [
      'Train',
      'Eat to Target',
      'Weigh In',
      'Steps',
    ]);
    expect(items.map(TodayText.icon).toSet(), hasLength(4));
    expect(StarterStep.values.map((s) => TodayText.starter(l10n, s)), [
      'Finish your first workout',
      'Log your first meal',
      'Log your weight',
      'Connect Apple Health',
      'Connect Strava',
    ]);
    expect(
      TodayText.starter(l10n, StarterStep.appleHealth, appleHealth: false),
      'Connect Health Connect',
    );
    expect(StarterStep.values.map(TodayText.starterIcon).toSet(), hasLength(5));
  });
}
