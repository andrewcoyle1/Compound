import 'dart:async';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_repository/image_repository.dart';

const _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

CameraImageData _image(int width) => CameraImageData(
  format: const CameraImageFormat(ImageFormatGroup.bgra8888, raw: 0),
  planes: [CameraImagePlane(bytes: Uint8List(8), bytesPerRow: width * 4)],
  height: 2,
  width: width,
);

/// The camera plugin's platform side: [cameras] to choose from, frames
/// sent with [frames], and what was asked of it.
class _FakeCameraPlatform extends CameraPlatform {
  List<CameraDescription> cameras = const [
    CameraDescription(
      name: 'front',
      lensDirection: CameraLensDirection.front,
      sensorOrientation: 270,
    ),
    _back,
  ];
  PlatformException? createError;
  final frames = StreamController<CameraImageData>.broadcast();
  final errors = StreamController<CameraErrorEvent>.broadcast();
  final created = <(CameraDescription, MediaSettings?)>[];
  final formats = <ImageFormatGroup>[];
  final flash = <FlashMode>[];
  final disposed = <int>[];

  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings? mediaSettings,
  ) async {
    if (createError case final error?) throw error;
    created.add((cameraDescription, mediaSettings));
    return 7;
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          1920,
          1080,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      );

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => errors.stream;

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      const Stream.empty();

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async => formats.add(imageFormatGroup);

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) => frames.stream;

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async =>
      flash.add(mode);

  @override
  Widget buildPreview(int cameraId) => const Text('preview');

  @override
  Future<void> dispose(int cameraId) async => disposed.add(cameraId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceLiveCamera', () {
    late _FakeCameraPlatform platform;

    setUp(() => CameraPlatform.instance = platform = _FakeCameraPlatform());
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('opens the back camera silently and streams BGRA frames', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final camera = DeviceLiveCamera();
      final frames = <LabelFrame>[];
      await camera.open(frames.add);

      expect(platform.created.single.$1, _back);
      expect(platform.created.single.$2?.enableAudio, isFalse);
      expect(
        platform.created.single.$2?.resolutionPreset,
        ResolutionPreset.veryHigh,
      );
      expect(platform.formats.single, ImageFormatGroup.bgra8888);

      platform.frames.add(_image(3));
      await pumpEventQueue();
      expect(frames.single.width, 3);
      expect(frames.single.bytesPerRow, 12);
      expect(frames.single.rotation, 0);

      await camera.setTorch(on: true);
      await camera.setTorch(on: false);
      expect(platform.flash, [FlashMode.torch, FlashMode.off]);

      await camera.close();
      await camera.close();
      expect(platform.disposed, [7]);
      // Closed, the torch has nothing to light.
      await camera.setTorch(on: true);
      expect(platform.flash, hasLength(2));
    });

    test('asks Android for NV21 and turns frames by the sensor', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final frames = <LabelFrame>[];
      await DeviceLiveCamera().open(frames.add);
      platform.frames.add(_image(4));
      await pumpEventQueue();

      expect(platform.formats.single, ImageFormatGroup.nv21);
      expect(frames.single.rotation, 90);
    });

    test('takes the only camera when none faces back', () async {
      platform.cameras = [platform.cameras.first];
      await DeviceLiveCamera().open((_) {});
      expect(platform.created.single.$1.name, 'front');
    });

    test('fails without a camera', () async {
      platform.cameras = [];
      await expectLater(
        DeviceLiveCamera().open((_) {}),
        throwsA(isA<StateError>()),
      );
    });

    for (final code in [
      'CameraAccessDenied',
      'CameraAccessDeniedWithoutPrompt',
      'CameraAccessRestricted',
    ]) {
      test('a refused camera ($code) is access denied', () async {
        platform.createError = PlatformException(code: code);
        await expectLater(
          DeviceLiveCamera().open((_) {}),
          throwsA(isA<PhotoAccessDeniedException>()),
        );
      });
    }

    test('passes on any other failure', () async {
      platform.createError = PlatformException(code: 'busy');
      await expectLater(
        DeviceLiveCamera().open((_) {}),
        throwsA(
          isA<CameraException>().having((error) => error.code, 'code', 'busy'),
        ),
      );
    });

    testWidgets('previews what the camera sees while open', (tester) async {
      final camera = DeviceLiveCamera();
      await tester.pumpWidget(camera.preview());
      expect(find.byType(CameraPreview), findsNothing);

      await tester.runAsync(() => camera.open((_) {}));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: camera.preview(),
        ),
      );
      expect(find.byType(CameraPreview), findsOneWidget);
      expect(find.text('preview'), findsOneWidget);
      await tester.runAsync(camera.close);
    });
  });

  group('labelFrame', () {
    final image = CameraImage.fromPlatformInterface(_image(5));
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('keeps the first plane, upright on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final frame = labelFrame(
        image,
        sensorOrientation: 90,
        deviceOrientation: DeviceOrientation.portraitUp,
      );
      expect(frame.bytes, hasLength(8));
      expect(frame.width, 5);
      expect(frame.height, 2);
      expect(frame.bytesPerRow, 20);
      expect(frame.rotation, 0);
    });

    test('on Android, turns by the sensor less the device', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      for (final (device, rotation) in [
        (DeviceOrientation.portraitUp, 90),
        (DeviceOrientation.landscapeLeft, 0),
        (DeviceOrientation.portraitDown, 270),
        (DeviceOrientation.landscapeRight, 180),
      ]) {
        expect(
          labelFrame(
            image,
            sensorOrientation: 90,
            deviceOrientation: device,
          ).rotation,
          rotation,
          reason: '$device',
        );
      }
    });
  });

  group('SampleLiveCamera', () {
    testWidgets('sends the label four times a second until closed', (
      tester,
    ) async {
      final camera = SampleLiveCamera(load: () async => Uint8List(3));
      final frames = <LabelFrame>[];
      await camera.open(frames.add);
      await tester.pump(const Duration(seconds: 1));
      expect(frames, hasLength(4));
      expect(frames.first.bytes, hasLength(3));
      expect(frames.first.rotation, 0);

      await camera.setTorch(on: true);
      await camera.close();
      await tester.pump(const Duration(seconds: 1));
      expect(frames, hasLength(4));
    });

    test('loads the bundled label photo', () async {
      final camera = SampleLiveCamera();
      await camera.open((_) {});
      await camera.close();
      final asset = await rootBundle.load(SampleLiveCamera.labelAsset);
      expect(asset.lengthInBytes, greaterThan(1000));
    });

    testWidgets('previews the label photo once open', (tester) async {
      final camera = SampleLiveCamera();
      await tester.pumpWidget(camera.preview());
      expect(find.byType(Image), findsNothing);

      await tester.runAsync(() => camera.open((_) {}));
      await tester.pumpWidget(camera.preview());
      expect(find.byType(Image), findsOneWidget);
      await camera.close();
    });
  });
}
