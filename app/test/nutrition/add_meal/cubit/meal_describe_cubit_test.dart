import 'package:compound/nutrition/add_meal/cubit/food_photo_scanner_cubit.dart';
import 'package:compound/nutrition/add_meal/cubit/meal_describe_cubit.dart';
import 'package:connectivity_repository/connectivity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';

import '../fake_ai.dart';
import '../recording_analytics.dart';

const _json = '''
{"items": [
  {"id": "1", "name": "Porridge", "amountGrams": 200, "calories": 180, "proteinGrams": 6},
  {"id": "2", "name": "Banana", "amountGrams": 120, "calories": 105}
]}''';

// Swift `MealDescribePresenterTests`, case for case. The amount
// sheet's confirm is the widget flow's.
void main() {
  late FakeConnectivityRepository connectivity;
  late List<void> blocked;
  late FakeAi ai;
  late RecordingAnalytics analytics;

  setUp(() {
    connectivity = FakeConnectivityRepository();
    blocked = [];
    connectivity.blocked.listen(blocked.add);
    ai = FakeAi()..json = _json;
    analytics = RecordingAnalytics();
  });

  MealDescribeCubit build([String text = 'Porridge and a banana']) =>
      MealDescribeCubit(
        connectivity: connectivity,
        ai: ai.repository,
        analytics: analytics,
      )..textChanged(text);

  group(MealDescribeCubit, () {
    test('a description is broken into items', () async {
      final cubit = build();
      final states = <MealDescribeState>[];
      final subscription = cubit.stream.listen(states.add);

      await cubit.analyse();
      await subscription.cancel();

      expect(states.first.status, EstimateStatus.analysing);
      expect(cubit.state.items.map((item) => item.name), [
        'Porridge',
        'Banana',
      ]);
      expect(cubit.state.status, EstimateStatus.analysed);
      expect(ai.calls.single.$1, 'mealDescribe');
      expect(ai.calls.single.$2, {'description': 'Porridge and a banana'});
      expect(analytics.names, [
        'MealDescribe_Submit',
        'MealDescribeView_Analyse_Success',
      ]);
      expect(analytics.events.first.$2, {'text_length': 21});
      expect(analytics.events.last.$2, {'item_count': 2});
    });

    test('an empty description is not submitted', () async {
      final cubit = build('   ');

      await cubit.analyse();

      expect(ai.calls, isEmpty);
      expect(cubit.state.status, EstimateStatus.idle);
    });

    test('a failed description stops the spinner and is reported', () async {
      ai.fails = true;
      final cubit = build('Porridge');

      await cubit.analyse();

      expect(cubit.state.status, EstimateStatus.failed);
      expect(analytics.names.last, 'MealDescribe_Error');
    });

    test('a description is held to the character limit', () {
      final cubit = build('a' * (MealDescribeCubit.characterLimit + 20));

      expect(cubit.state.text.length, MealDescribeCubit.characterLimit);
    });

    test('Analyze is enabled only with a description, and not while one is '
        'out', () async {
      expect(build('  ').state.canAnalyse, isFalse);
      final cubit = build('Porridge');
      expect(cubit.state.canAnalyse, isTrue);

      final pending = cubit.analyse();
      expect(cubit.state.canAnalyse, isFalse);
      await cubit.analyse();
      await pending;
      expect(ai.calls, hasLength(1));
    });

    test('unreadable output is an error, not a crash', () async {
      ai.json = 'I am not sure what you ate.';
      final cubit = build('Porridge');

      await cubit.analyse();

      expect(cubit.state.status, EstimateStatus.failed);
      expect(cubit.state.items, isEmpty);
    });

    test('Add All adds every result once; a new analysis allows it '
        'again', () async {
      final cubit = build();
      await cubit.analyse();

      cubit
        ..addAll()
        ..addAll();

      final items = [for (final item in cubit.state.items) item.mealItem()];
      expect(items.map((item) => item.displayName), ['Porridge', 'Banana']);
      expect(items.map((item) => item.amount), [200, 120]);
      expect(items.first.nutrients.values[NutrientKey.calories], 180);
      expect(cubit.state.addedAll, isTrue);
      expect(
        analytics.names.where((name) => name == 'MealDescribe_AddAll'),
        hasLength(1),
      );

      await cubit.analyse();
      expect(cubit.state.addedAll, isFalse);
    });

    test('resubmitting clears the previous answer', () async {
      final cubit = build();
      await cubit.analyse();

      ai.json =
          '{"items": [{"id": "3", "name": "Toast", "amountGrams": 40, '
          '"calories": 110}]}';
      cubit.textChanged('Toast');
      await cubit.analyse();

      expect(cubit.state.items.map((item) => item.name), ['Toast']);
    });

    test('tapping a result gives the estimate for the amount sheet, and '
        'is tracked', () async {
      final cubit = build();
      await cubit.analyse();

      final item = cubit.state.items.first;
      cubit.resultTapped(item);
      final food = item.estimatedFood(now: DateTime.utc(2026, 10, 16));

      // At the estimated 200 g, the sheet reads back the 180 kcal.
      expect(food.name, 'Porridge');
      expect(food.nutrients.values[NutrientKey.calories], 180 / 200 * 100);
      expect(analytics.names.last, 'MealDescribe_AddItem');
      expect(analytics.events.last.$2, {'item_name': 'Porridge'});
      expect(cubit.state.items, hasLength(2));
    });

    test('a nutrient the model omitted is absent', () async {
      final cubit = build();
      await cubit.analyse();

      final banana = cubit.state.items.last.estimatedFood(
        now: DateTime.utc(2026, 10, 16),
      );

      expect(banana.nutrients.values[NutrientKey.calories], 105 / 120 * 100);
      expect(banana.nutrients.values.containsKey(NutrientKey.protein), isFalse);
    });

    test('an answer that returns after the tab closed is dropped', () async {
      final cubit = build();
      final pending = cubit.analyse();
      await cubit.close();
      await pending;
      ai.fails = true;
      final failing = build();
      final failure = failing.analyse();
      await failing.close();
      await failure;

      expect(ai.calls, hasLength(2));
    });

    // testOfflineADescriptionIsNotSentAndSaysYoureOffline
    test('offline a description is not sent, and says so', () async {
      connectivity.offline = true;
      final cubit = build();

      await cubit.analyse();
      await pumpEventQueue();

      expect(ai.calls, isEmpty);
      expect(cubit.state.status, EstimateStatus.idle);
      expect(blocked, hasLength(1));
    });
  });
}
