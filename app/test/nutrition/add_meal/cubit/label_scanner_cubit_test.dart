import 'dart:async';
import 'dart:typed_data';

import 'package:compound/nutrition/add_meal/cubit/food_photo_scanner_cubit.dart'
    show CameraState;
import 'package:compound/nutrition/add_meal/cubit/label_scanner_cubit.dart';
import 'package:connectivity_repository/connectivity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:image_repository/image_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../fake_ai.dart';
import '../recording_analytics.dart';

class _MockFoodRepository extends Mock implements FoodRepository;

class _FakeFood extends Fake implements FoodModel;

/// Reads every photo as [text], or throws [error]; [gate], when set, holds
/// the answer until it completes.
class _Reader implements LabelTextReader {
  String text = 'Energy 46kcal\nProtein 1.2 g';
  Exception? error;
  Completer<void>? gate;
  final photos = <Uint8List>[];

  @override
  Future<String> read(Uint8List jpeg) async {
    photos.add(jpeg);
    await gate?.future;
    if (error case final error?) throw error;
    return text;
  }
}

String _label({String measurementMethod = 'weight'}) =>
    '''
{"name": "Oat Milk", "measurementMethod": "$measurementMethod",
 "calories": 46, "protein": 1.2, "carbs": 6.6, "fatTotal": 1.5}''';

// Swift `BarcodeScannerPresenterTests`, label mode, case for case. The
// label's decoding (volume, nutrients left out, an unknown method) is
// `ai_repository`'s and tested there, and "saving stores it and resumes
// scanning" has no standalone Save to Library here.
void main() {
  late FakeConnectivityRepository connectivity;
  late List<void> blocked;
  const uid = 'user-1';
  late FakeAi ai;
  late FoodRepository foods;
  late RecordingAnalytics analytics;
  late FakePhotoPicker picker;
  late _Reader reader;

  setUpAll(() => registerFallbackValue(_FakeFood()));

  setUp(() {
    connectivity = FakeConnectivityRepository();
    blocked = [];
    connectivity.blocked.listen(blocked.add);
    ai = FakeAi()..json = _label();
    foods = _MockFoodRepository();
    analytics = RecordingAnalytics();
    picker = FakePhotoPicker();
    reader = _Reader();
    when(() => foods.saveFood(any())).thenAnswer((_) async {});
  });

  LabelScannerCubit build() => LabelScannerCubit(
    connectivity: connectivity,
    uid: uid,
    ai: ai.repository,
    foodRepository: foods,
    analytics: analytics,
    picker: picker,
    reader: reader,
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

  // On-device reading of a label photo, which Swift does live with
  // DataScannerViewController.
  group('scan', () {
    test("a photo's text is read on the device for the field", () async {
      final cubit = build();
      final states = <LabelScannerState>[];
      final subscription = cubit.stream.listen(states.add);

      await cubit.scan(PhotoSource.camera);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(states, [
        const LabelScannerState(status: LabelStatus.reading),
        const LabelScannerState(
          status: LabelStatus.read,
          text: 'Energy 46kcal\nProtein 1.2 g',
        ),
      ]);
      expect(picker.picks.single, (PhotoSource.camera, PhotoSize.labelPhoto));
      expect(reader.photos.single, picker.photo);
      expect(ai.calls, isEmpty);
    });

    test('a library photo is read the same way', () async {
      final cubit = build();

      await cubit.scan(PhotoSource.library);

      expect(picker.picks.single.$1, PhotoSource.library);
      expect(cubit.state.status, LabelStatus.read);
    });

    test('a photo with no text is unreadable', () async {
      reader.text = '';
      final cubit = build();

      await cubit.scan(PhotoSource.camera);

      expect(
        cubit.state,
        const LabelScannerState(status: LabelStatus.unreadable),
      );
    });

    test('a reader failure is reported as unreadable', () async {
      reader.error = Exception('vision');
      final cubit = build();

      await cubit.scan(PhotoSource.camera);

      expect(cubit.state.status, LabelStatus.unreadable);
      expect(analytics.names, ['BarcodeScanner_LabelError']);
    });

    test('a cancelled photo changes nothing', () async {
      picker.photo = null;
      final cubit = build();

      await cubit.scan(PhotoSource.camera);

      expect(cubit.state, const LabelScannerState());
      expect(reader.photos, isEmpty);
    });

    test('a refused camera says so, and Settings can be opened', () async {
      picker.error = const PhotoAccessDeniedException();
      final cubit = build();

      await cubit.scan(PhotoSource.camera);
      await cubit.openSettings();

      expect(cubit.state.camera, CameraState.denied);
      expect(picker.settingsOpened, 1);
      expect(analytics.names, [
        'BarcodeScanner_CameraDenied',
        'BarcodeScanner_OpenSettings',
      ]);
    });

    test('a camera that cannot open is unavailable', () async {
      picker.error = Exception('no camera');
      final cubit = build();

      await cubit.scan(PhotoSource.camera);

      expect(cubit.state.camera, CameraState.unavailable);
    });

    test('nothing else starts while a photo is read', () async {
      reader.gate = Completer();
      final cubit = build();
      final pending = cubit.scan(PhotoSource.camera);
      await Future<void>.delayed(Duration.zero);

      await cubit.scan(PhotoSource.camera);
      await cubit.parse('Energy 46kcal');
      reader.gate!.complete();
      await pending;

      expect(picker.picks, hasLength(1));
      expect(ai.calls, isEmpty);
      expect(cubit.state.status, LabelStatus.read);
    });

    test('a read that returns after the tab closed is dropped', () async {
      reader.gate = Completer();
      final cubit = build();
      final pending = cubit.scan(PhotoSource.camera);
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      reader.gate!.complete();
      await pending;

      reader
        ..gate = Completer()
        ..error = Exception('vision');
      final failing = build();
      final failure = failing.scan(PhotoSource.camera);
      await Future<void>.delayed(Duration.zero);
      await failing.close();
      reader.gate!.complete();
      await failure;

      expect(reader.photos, hasLength(2));
    });

    test('a photo that arrives after the tab closed is dropped', () async {
      final cubit = build();
      await cubit.close();

      await cubit.scan(PhotoSource.camera);
      picker.error = const PhotoAccessDeniedException();
      await cubit.scan(PhotoSource.camera);
      picker.error = Exception('no camera');
      await cubit.scan(PhotoSource.camera);

      expect(reader.photos, isEmpty);
    });

    // testOfflineALabelIsNotSentAndSaysYoureOffline
    test('offline a label is not sent, and says so', () async {
      connectivity.offline = true;
      final cubit = build();

      await cubit.parse('Energy 46kcal');
      await pumpEventQueue();

      expect(ai.calls, isEmpty);
      expect(cubit.state, const LabelScannerState());
      expect(blocked, hasLength(1));
    });
  });
}
