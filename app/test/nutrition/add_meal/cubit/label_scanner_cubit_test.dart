import 'package:compound/nutrition/add_meal/cubit/label_scanner_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../fake_ai.dart';
import '../recording_analytics.dart';

class _MockFoodRepository extends Mock implements FoodRepository;

class _FakeFood extends Fake implements FoodModel;

String _label({String measurementMethod = 'weight'}) =>
    '''
{"name": "Oat Milk", "measurementMethod": "$measurementMethod",
 "calories": 46, "protein": 1.2, "carbs": 6.6, "fatTotal": 1.5}''';

// Swift `BarcodeScannerPresenterTests`, label mode, case for case. The
// label's decoding (volume, nutrients left out, an unknown method) is
// `ai_repository`'s and tested there; "offline a label is not sent" is
// left out (no offline pre-check), and "saving stores it and resumes
// scanning" has no standalone Save to Library here.
void main() {
  const uid = 'user-1';
  late FakeAi ai;
  late FoodRepository foods;
  late RecordingAnalytics analytics;

  setUpAll(() => registerFallbackValue(_FakeFood()));

  setUp(() {
    ai = FakeAi()..json = _label();
    foods = _MockFoodRepository();
    analytics = RecordingAnalytics();
    when(() => foods.saveFood(any())).thenAnswer((_) async {});
  });

  LabelScannerCubit build() => LabelScannerCubit(
    uid: uid,
    ai: ai.repository,
    foodRepository: foods,
    analytics: analytics,
  );

  group(LabelScannerCubit, () {
    test('a parsed label becomes a food, authored by the user', () async {
      final cubit = build();
      final states = <LabelScannerState>[];
      final subscription = cubit.stream.listen(states.add);

      await cubit.parse('  Energy 46kcal per 100ml ');
      await subscription.cancel();

      expect(
        states.first,
        const LabelScannerState(status: LabelStatus.parsing),
      );
      final food = cubit.state.food!;
      expect(cubit.state.status, LabelStatus.parsed);
      expect(food.name, 'Oat Milk');
      expect(food.authorId, uid);
      expect(food.nutrients.values[NutrientKey.calories], 46);
      expect(food.nutrients.values[NutrientKey.protein], 1.2);
      expect(food.nutrients.values[NutrientKey.fatTotal], 1.5);
      expect(ai.calls.single.$1, 'nutritionLabelAnalyze');
      expect(ai.calls.single.$2, {'labelText': 'Energy 46kcal per 100ml'});
      expect(analytics.names, [
        'BarcodeScanner_ParseLabel',
        'BarcodeScannerView_ParseLabel_Success',
      ]);
    });

    test('a volume label produces a volume food', () async {
      ai.json = _label(measurementMethod: 'volume');
      final cubit = build();

      await cubit.parse('Energy 46kcal');

      expect(cubit.state.food?.measurementMethod, MeasurementMethod.volume);
    });

    test('parsing without any text does nothing', () async {
      final cubit = build();

      await cubit.parse('   ');

      expect(ai.calls, isEmpty);
      expect(cubit.state, const LabelScannerState());
    });

    test('a second parse while one is out is not sent', () async {
      final cubit = build();
      final pending = cubit.parse('Energy 46kcal');
      await cubit.parse('Energy 46kcal');
      await pending;

      expect(ai.calls, hasLength(1));
    });

    test('a failed parse is reported and stops the spinner', () async {
      ai.fails = true;
      final cubit = build();

      await cubit.parse('Energy 46kcal');

      expect(cubit.state, const LabelScannerState(status: LabelStatus.failed));
      expect(analytics.names.last, 'BarcodeScanner_LabelError');
      expect(analytics.events.last.$2?['error'], isA<String>());
    });

    test('unreadable analyser output is an error, not a crash', () async {
      ai.json = 'Sorry, I could not read that label.';
      final cubit = build();

      await cubit.parse('Energy 46kcal');

      expect(cubit.state.status, LabelStatus.failed);
      expect(cubit.state.food, isNull);
    });

    test('reparsing clears the previous error', () async {
      ai.fails = true;
      final cubit = build();
      await cubit.parse('Energy 46kcal');

      ai.fails = false;
      await cubit.parse('Energy 46kcal');

      expect(cubit.state.status, LabelStatus.parsed);
      expect(cubit.state.food, isNotNull);
    });

    test('a label read while logging is saved, then handed on for the '
        'plate', () async {
      final cubit = build();
      await cubit.parse('Energy 46kcal');

      await cubit.use();

      final saved =
          verify(() => foods.saveFood(captureAny())).captured.single
              as FoodModel;
      expect(saved.name, 'Oat Milk');
      expect(
        cubit.state,
        LabelScannerState(status: LabelStatus.saved, food: saved),
      );
      expect(analytics.names.skip(2), [
        'BarcodeScanner_SaveIngredient',
        'BarcodeScannerView_SaveIngredient_Success',
      ]);
      expect(analytics.events[2].$2, {'ingredient_name': 'Oat Milk'});
    });

    test('saving without a food does nothing', () async {
      final cubit = build();

      await cubit.use();
      expect(cubit.state, const LabelScannerState());
      verifyNever(() => foods.saveFood(any()));
    });

    test('a failed save keeps the parsed food', () async {
      when(() => foods.saveFood(any()))
          .thenAnswer((_) async => throw Exception('refused'));
      final cubit = build();
      await cubit.parse('Energy 46kcal');

      await cubit.use();

      expect(cubit.state.status, LabelStatus.saveFailed);
      expect(cubit.state.food?.name, 'Oat Milk');
      expect(analytics.names.last, 'BarcodeScanner_LabelError');
    });

    test('a second Use while saving is ignored', () async {
      final cubit = build();
      await cubit.parse('Energy 46kcal');

      final first = cubit.use();
      await cubit.use();
      await first;

      verify(() => foods.saveFood(any())).called(1);
    });

    test('dismissing a result clears it', () async {
      final cubit = build();
      await cubit.parse('Energy 46kcal');

      cubit.dismiss();

      expect(cubit.state, const LabelScannerState());
    });

    test('a result that returns after the tab closed is dropped', () async {
      final cubit = build();
      final pending = cubit.parse('Energy 46kcal');
      await cubit.close();
      await pending;

      ai.fails = true;
      final failing = build();
      final failure = failing.parse('Energy 46kcal');
      await failing.close();
      await failure;

      expect(ai.calls, hasLength(2));
    });
  });
}
