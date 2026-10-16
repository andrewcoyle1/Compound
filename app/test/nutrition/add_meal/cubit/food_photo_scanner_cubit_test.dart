import 'dart:convert';

import 'package:compound/nutrition/add_meal/cubit/food_photo_scanner_cubit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:image_repository/image_repository.dart';

import '../fake_ai.dart';
import '../recording_analytics.dart';

/// One item in the shape the analyser returns it.
String _json({String name = 'Scrambled Eggs', String extra = ''}) =>
    '''
{"items": [{
  "id": "1", "name": "$name", "amountGrams": 150, "calories": 220,
  "proteinGrams": 14, "carbGrams": 2, "fatGrams": 17 $extra
}]}''';

// Swift `FoodPhotoScannerPresenterTests`, case for case, less "offline a
// photo is not sent": Flutter has no offline pre-check.
void main() {
  late FakeAi ai;
  late FakePhotoPicker picker;
  late RecordingAnalytics analytics;

  setUp(() {
    ai = FakeAi()..json = _json();
    picker = FakePhotoPicker();
    analytics = RecordingAnalytics();
  });

  FoodPhotoScannerCubit build() => FoodPhotoScannerCubit(
    ai: ai.repository,
    picker: picker,
    analytics: analytics,
  );

  group(FoodPhotoScannerCubit, () {
    test('a photo is analysed into items', () async {
      final cubit = build();
      final states = <FoodPhotoScannerState>[];
      final subscription = cubit.stream.listen(states.add);

      await cubit.takePhoto();
      await subscription.cancel();

      expect(states.first.status, EstimateStatus.analysing);
      expect(cubit.state.status, EstimateStatus.analysed);
      expect(cubit.state.items.map((item) => item.name), ['Scrambled Eggs']);
      expect(analytics.names, [
        'FoodPhotoScanner_Capture',
        'FoodPhotoScannerView_Analyse_Success',
      ]);
      expect(analytics.events.last.$2, {'item_count': 1});
    });

    test('the photo taken reaches the analyser, at the food size', () async {
      await build().takePhoto();

      expect(picker.picks, [(PhotoSource.camera, PhotoSize.foodPhoto)]);
      expect(ai.calls.single.$1, 'foodAnalyze');
      expect(ai.calls.single.$2, {'imageBase64': base64Encode(picker.photo!)});
    });

    test('unreadable output is an error, not a crash', () async {
      ai.json = 'I could not see the plate clearly.';
      final cubit = build();

      await cubit.takePhoto();

      expect(cubit.state.status, EstimateStatus.failed);
      expect(cubit.state.items, isEmpty);
    });

    test('a failed analysis stops the spinner and is reported', () async {
      ai.fails = true;
      final cubit = build();

      await cubit.takePhoto();

      expect(cubit.state.status, EstimateStatus.failed);
      expect(analytics.names.last, 'FoodPhotoScanner_Error');
      expect(analytics.events.last.$2?['error'], isA<String>());
    });

    test('Add All adds every result once', () async {
      ai.json = '''
{"items": [
  {"id": "1", "name": "Eggs", "amountGrams": 150, "calories": 220},
  {"id": "2", "name": "Toast", "amountGrams": 40, "calories": 110}
]}''';
      final cubit = build();
      await cubit.takePhoto();

      cubit
        ..addAll()
        ..addAll();

      final items = [for (final item in cubit.state.items) item.mealItem()];
      expect(items.map((item) => item.displayName), ['Eggs', 'Toast']);
      expect(items.map((item) => item.amount), [150, 40]);
      expect(cubit.state.addedAll, isTrue);
      expect(
        analytics.names.where((name) => name == 'FoodPhotoScanner_AddAll'),
        hasLength(1),
      );
      expect(analytics.events.last.$2, {'item_count': 2});
    });

    test('Add All with nothing found adds nothing', () {
      final cubit = build()..addAll();
      expect(cubit.state.addedAll, isFalse);
      expect(analytics.events, isEmpty);
    });

    test("a second photo clears the first one's outcome", () async {
      ai.fails = true;
      final cubit = build();
      await cubit.takePhoto();
      expect(cubit.state.status, EstimateStatus.failed);

      ai
        ..fails = false
        ..json = _json(name: 'Porridge');
      await cubit.takePhoto();

      expect(cubit.state.status, EstimateStatus.analysed);
      expect(cubit.state.items.map((item) => item.name), ['Porridge']);
      expect(cubit.state.addedAll, isFalse);
    });

    test('retaking clears everything from the last shot', () async {
      final cubit = build();
      await cubit.takePhoto();
      cubit.addAll();
      picker.photo = null;
      await cubit.retake();

      expect(cubit.state, const FoodPhotoScannerState());
      expect(picker.picks, hasLength(2));
    });

    test("an item carries the model's figures unscaled", () async {
      final cubit = build();
      await cubit.takePhoto();

      final item = cubit.state.items.single.mealItem();

      expect(item.displayName, 'Scrambled Eggs');
      expect(item.amount, 150);
      expect(item.unit, 'g');
      expect(item.resolvedGrams, 150);
      expect(item.nutrients.values[NutrientKey.calories], 220);
      expect(item.nutrients.values[NutrientKey.protein], 14);
    });

    test('a nutrient the model omitted is absent', () async {
      ai.json =
          '{"items": [{"id": "1", "name": "Toast", "amountGrams": 40, '
          '"calories": 110}]}';
      final cubit = build();
      await cubit.takePhoto();

      final item = cubit.state.items.single.mealItem();

      expect(item.nutrients.values[NutrientKey.calories], 110);
      expect(item.nutrients.values.containsKey(NutrientKey.protein), isFalse);
      expect(item.nutrients.values.containsKey(NutrientKey.fatTotal), isFalse);
    });

    test('a recognised food is pointed at', () async {
      ai.json = _json(extra: ', "ingredientId": "food-1"');
      final cubit = build();
      await cubit.takePhoto();

      expect(cubit.state.items.single.mealItem().sourceId, 'food-1');
    });

    test('tapping a result gives the estimate per 100 g for the amount '
        'sheet', () async {
      final cubit = build();
      await cubit.takePhoto();

      final item = cubit.state.items.single;
      cubit.resultTapped(item);
      final food = item.estimatedFood(now: DateTime.utc(2026, 10, 16));

      expect(food.name, 'Scrambled Eggs');
      // Opened at 150 g, the sheet reads back the 220 kcal estimated.
      expect(food.nutrients.values[NutrientKey.calories], 220 / 150 * 100);
      expect(analytics.names.last, 'FoodPhotoScanner_AddItem');
      expect(analytics.events.last.$2, {'item_name': 'Scrambled Eggs'});
    });

    test('a refused camera is told apart from a missing one', () async {
      picker.error = const PhotoAccessDeniedException();
      final refused = build();
      await refused.takePhoto();
      await refused.openSettings();

      picker.error = PlatformException(code: 'no_available_camera');
      final missing = build();
      await missing.takePhoto();

      expect(refused.state.camera, CameraState.denied);
      expect(picker.settingsOpened, 1);
      expect(analytics.names, [
        'FoodPhotoScanner_CameraDenied',
        'FoodPhotoScanner_OpenSettings',
      ]);
      expect(missing.state.camera, CameraState.unavailable);
      expect(ai.calls, isEmpty);
    });

    test('a cancelled photo leaves the tab as it was', () async {
      picker.photo = null;
      final cubit = build();

      await cubit.takePhoto();

      expect(cubit.state, const FoodPhotoScannerState());
      expect(ai.calls, isEmpty);
      expect(analytics.events, isEmpty);
    });

    test('a photo that returns after the tab closed is not sent', () async {
      final cubit = build();
      final pending = cubit.takePhoto();
      await cubit.close();
      await pending;

      expect(ai.calls, isEmpty);
    });
  });
}
