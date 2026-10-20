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

  /// What the next frames read as; [frameError] makes them fail.
  String frameText = _label1;
  Exception? frameError;
  int frames = 0;

  @override
  Future<String> readFrame(LabelFrame frame) async {
    frames++;
    await gate?.future;
    if (frameError case final error?) throw error;
    return frameText;
  }

  @override
  Future<String> read(Uint8List jpeg) async {
    photos.add(jpeg);
    await gate?.future;
    if (error case final error?) throw error;
    return text;
  }
}

const _label1 =
    'Nutrition Facts\nEnergy 1550 kJ / 370 kcal\nFat 6.5 g\nProtein 13 g';

/// [_label1] with one value read differently.
const _label2 =
    'Nutrition Facts\nEnergy 1550 kJ / 370 kcal\nFat 6.6 g\nProtein 13 g';

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
  late FakeLiveCamera camera;

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
    camera = FakeLiveCamera();
    when(() => foods.saveFood(any())).thenAnswer((_) async {});
  });

  LabelScannerCubit build({Duration interval = Duration.zero}) =>
      LabelScannerCubit(
        connectivity: connectivity,
        uid: uid,
        ai: ai.repository,
        foodRepository: foods,
        analytics: analytics,
        picker: picker,
        reader: reader,
        camera: camera,
        interval: interval,
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

    test('Scan Again forgets the result and opens the camera', () async {
      final cubit = build();
      await cubit.parse('Energy 46kcal');

      await cubit.start();

      expect(cubit.state.status, LabelStatus.scanning);
      expect(cubit.state.food, isNull);
      expect(camera.isOpen, isTrue);
      await cubit.close();
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
        const LabelScannerState(),
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

    test('a cancelled photo goes back to the live camera', () async {
      picker.photo = null;
      final cubit = build();
      await cubit.start();

      await cubit.scan(PhotoSource.library);

      expect(cubit.state.status, LabelStatus.scanning);
      expect(camera.opened, 2);
      expect(camera.closed, 1);
      expect(reader.photos, isEmpty);
      await cubit.close();
    });

    test('a cancelled photo leaves a refused camera closed', () async {
      camera.error = const PhotoAccessDeniedException();
      picker.photo = null;
      final cubit = build();
      await cubit.start();

      await cubit.scan(PhotoSource.library);

      expect(cubit.state, const LabelScannerState(camera: CameraState.denied));
      expect(camera.opened, 1);
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

  group('live', () {
    // Lets the camera's queue and a frame's read finish.
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('opens the camera and offers the torch', () async {
      final cubit = build();
      await cubit.start();

      expect(
        cubit.state,
        const LabelScannerState(
          status: LabelStatus.scanning,
          live: true,
          hasTorch: true,
        ),
      );
      expect(camera.opened, 1);
      await cubit.close();
      expect(camera.isOpen, isFalse);
    });

    test('a label that holds still over two reads is sent once', () async {
      final cubit = build();
      await cubit.start();

      camera.send();
      await settle();
      expect(cubit.state.status, LabelStatus.scanning);
      expect(ai.calls, isEmpty);

      camera.send();
      await settle();

      expect(ai.calls.single.$2, {'labelText': _label1});
      expect(cubit.state.status, LabelStatus.parsed);
      expect(cubit.state.food?.name, 'Oat Milk');
      expect(camera.isOpen, isFalse);
      expect(analytics.names.first, 'BarcodeScanner_LabelLocked');

      // The camera is closed; nothing more is read or sent.
      camera.send();
      await settle();
      expect(reader.frames, 2);
      expect(ai.calls, hasLength(1));
    });

    test('the locked text goes to the field first', () async {
      final cubit = build();
      final states = <LabelScannerState>[];
      final subscription = cubit.stream.listen(states.add);
      await cubit.start();

      camera.send();
      await settle();
      camera.send();
      await settle();
      await subscription.cancel();

      expect(
        states,
        contains(
          const LabelScannerState(status: LabelStatus.read, text: _label1),
        ),
      );
    });

    test('values that change between reads do not lock on', () async {
      final cubit = build();
      await cubit.start();

      for (final text in [_label1, _label2, _label1, _label2]) {
        reader.frameText = text;
        camera.send();
        await settle();
      }

      expect(reader.frames, 4);
      expect(ai.calls, isEmpty);
      expect(cubit.state.status, LabelStatus.scanning);
      await cubit.close();
    });

    test('text that is not a label never locks on', () async {
      reader.frameText = 'Ingredients: oats, water, salt 0.1 g';
      final cubit = build();
      await cubit.start();

      for (var i = 0; i < 3; i++) {
        camera.send();
        await settle();
      }

      expect(ai.calls, isEmpty);
      await cubit.close();
    });

    test('a frame that cannot be read is skipped', () async {
      reader.frameError = Exception('vision');
      final cubit = build();
      await cubit.start();

      camera
        ..send()
        ..send();
      await settle();
      camera.send();
      await settle();

      expect(reader.frames, 2);
      expect(ai.calls, isEmpty);
      expect(cubit.state.status, LabelStatus.scanning);
      await cubit.close();
    });

    test('frames are read at most once an interval', () async {
      final cubit = build(interval: const Duration(hours: 1));
      await cubit.start();

      camera.send();
      await settle();
      camera.send();
      await settle();

      expect(reader.frames, 1);
      await cubit.close();
    });

    test('never more than one frame is read at a time', () async {
      reader.gate = Completer();
      final cubit = build();
      await cubit.start();

      camera.send();
      await settle();
      camera.send();
      await settle();
      expect(reader.frames, 1);

      reader.gate!.complete();
      await settle();
      camera.send();
      await settle();
      expect(reader.frames, 2);
      await cubit.close();
    });

    test('a read that returns after the tab closed is dropped', () async {
      reader.gate = Completer();
      final cubit = build();
      await cubit.start();
      camera.send();
      await settle();

      await cubit.close();
      reader.gate!.complete();
      await settle();

      expect(ai.calls, isEmpty);
    });

    test('offline, the locked label waits in the field', () async {
      connectivity.offline = true;
      final cubit = build();
      await cubit.start();

      camera
        ..send()
        ..send();
      await settle();
      camera.send();
      await settle();

      expect(ai.calls, isEmpty);
      expect(
        cubit.state,
        const LabelScannerState(status: LabelStatus.read, text: _label1),
      );
      expect(blocked, hasLength(1));
      expect(camera.isOpen, isFalse);
    });

    test('Scan Again after a result locks on afresh', () async {
      final cubit = build();
      await cubit.start();
      camera.send();
      await settle();
      camera.send();
      await settle();

      await cubit.start();
      camera.send();
      await settle();
      expect(ai.calls, hasLength(1));
      camera.send();
      await settle();

      expect(ai.calls, hasLength(2));
      expect(camera.opened, 2);
    });

    test('typing a label while the camera looks closes it', () async {
      final cubit = build();
      await cubit.start();

      await cubit.parse('Energy 46kcal');
      await settle();

      expect(cubit.state.status, LabelStatus.parsed);
      expect(camera.isOpen, isFalse);
    });

    test('a refused camera says so, and opens once allowed', () async {
      camera.error = const PhotoAccessDeniedException();
      final cubit = build();
      await cubit.start();

      expect(cubit.state, const LabelScannerState(camera: CameraState.denied));
      expect(analytics.names, ['BarcodeScanner_CameraDenied']);

      // Back from Settings, allowed.
      camera.error = null;
      await cubit.pause();
      await cubit.resume();

      expect(cubit.state.live, isTrue);
      expect(camera.opened, 2);
      await cubit.close();
    });

    test('a camera that cannot open is unavailable', () async {
      camera.error = Exception('no camera');
      final cubit = build();
      await cubit.start();

      expect(
        cubit.state,
        const LabelScannerState(camera: CameraState.unavailable),
      );

      await cubit.resume();
      expect(camera.opened, 1);
    });

    test('the camera closes in the background and opens on return', () async {
      final cubit = build();
      await cubit.start();
      await cubit.toggleTorch();

      await cubit.pause();
      expect(camera.isOpen, isFalse);
      expect(cubit.state.live, isFalse);
      expect(cubit.state.torch, isFalse);
      camera.send();
      expect(reader.frames, 0);

      await cubit.resume();
      expect(camera.isOpen, isTrue);
      expect(cubit.state.live, isTrue);
      await cubit.close();
    });

    test('pausing while the camera opens closes it after', () async {
      camera.openGate = Completer();
      final cubit = build();
      final starting = cubit.start();
      await settle();
      final pausing = cubit.pause();
      camera.openGate!.complete();
      await starting;
      await pausing;

      expect(camera.opened, 1);
      expect(camera.closed, 1);
      expect(camera.isOpen, isFalse);
      expect(cubit.state.live, isFalse);
      await cubit.close();
    });

    test('the torch lights and goes out', () async {
      final cubit = build();
      await cubit.start();

      await cubit.toggleTorch();
      expect(cubit.state.torch, isTrue);
      expect(camera.torch, isTrue);

      await cubit.toggleTorch();
      expect(cubit.state.torch, isFalse);
      expect(camera.torch, isFalse);
      await cubit.close();
    });

    test('a camera without a torch loses the button', () async {
      camera.torchError = Exception('no flash');
      final cubit = build();
      await cubit.start();

      await cubit.toggleTorch();

      expect(cubit.state.hasTorch, isFalse);
      expect(cubit.state.torch, isFalse);
      await cubit.close();
    });

    test('a torch answer after the camera closed is dropped', () async {
      final cubit = build();
      await cubit.start();
      await cubit.pause();

      await cubit.toggleTorch();
      camera.torchError = Exception('no flash');
      await cubit.toggleTorch();

      expect(cubit.state.hasTorch, isFalse);
      expect(cubit.state.torch, isFalse);
      await cubit.close();
      await cubit.start();
    });
  });

  group('labelKey', () {
    test('is the values of an English label, in order of size', () {
      expect(
        labelKey('Protein 13 g\nEnergy 1550 kJ / 370 kcal\nFat 6,5 g'),
        '13 1550 370 6.5',
      );
      expect(labelKey('Calories 230\nProtein 3g'), '3');
    });

    test('reads Spanish labels', () {
      expect(labelKey('Valor energético 1550 kJ\nProteínas 13 g'), '13 1550');
    });

    test('is null for text that is not a nutrition label', () {
      expect(labelKey(''), isNull);
      expect(labelKey('Energy 1550 kJ\nFat 6 g'), isNull);
      expect(labelKey('Protein 13 g'), isNull);
    });
  });
}
