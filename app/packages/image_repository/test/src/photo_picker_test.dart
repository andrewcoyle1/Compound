import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_repository/image_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockImagePicker extends Mock implements ImagePicker;

/// flutter_image_compress's platform, recording the call and answering
/// [result].
class _FakeCompress extends Fake implements FlutterImageCompressPlatform {
  new(this.result);

  final Uint8List? result;
  final calls = <(String, int, int, int)>[];

  @override
  Future<Uint8List?> compressWithFile(
    String path, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) async {
    calls.add((path, minWidth, minHeight, quality));
    return result;
  }
}

/// A [width] by [height] PNG written to a temporary file; its path.
Future<String> _photo(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint(),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final directory = await Directory.systemTemp.createTemp('photo_picker');
  addTearDown(() => directory.delete(recursive: true));
  final file = File('${directory.path}/photo.png');
  await file.writeAsBytes(png!.buffer.asUint8List());
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

  setUpAll(() => registerFallbackValue(ImageSource.camera));

  group('PhotoSize', () {
    test("keeps Swift's sizes", () {
      for (final size in [
        PhotoSize.avatar,
        PhotoSize.foodImage,
        PhotoSize.recipeImage,
        PhotoSize.gymImage,
      ]) {
        expect((size.maxDimension, size.quality), (1280, 70));
      }
      for (final size in [
        PhotoSize.progressPhoto,
        PhotoSize.foodPhoto,
        PhotoSize.labelPhoto,
      ]) {
        expect((size.maxDimension, size.quality), (1600, 80));
      }
    });

    test('frames each kind of photo its own way', () {
      expect(PhotoSize.avatar.crop, PhotoCrop.circle);
      expect(PhotoSize.foodImage.crop, PhotoCrop.square);
      expect(PhotoSize.recipeImage.crop, PhotoCrop.wide);
      expect(PhotoSize.gymImage.crop, PhotoCrop.free);
      expect(PhotoSize.progressPhoto.crop, PhotoCrop.portrait);
      expect(PhotoSize.foodPhoto.crop, PhotoCrop.none);
      expect(PhotoSize.labelPhoto.crop, PhotoCrop.free);
      expect((PhotoCrop.portrait.ratioX, PhotoCrop.portrait.ratioY), (3, 4));
      expect((PhotoCrop.wide.ratioX, PhotoCrop.wide.ratioY), (16, 9));
    });
  });

  group('DevicePhotoPicker', () {
    late _MockImagePicker picker;
    late List<(String, PhotoCrop, CropLook)> crops;
    late List<(String, PhotoSize)> compressions;
    String? cropped;
    const look = CropLook(title: 'Crop');

    setUp(() {
      picker = _MockImagePicker();
      crops = [];
      compressions = [];
      cropped = 'cropped.jpg';
    });

    DevicePhotoPicker device() => DevicePhotoPicker(
      picker: picker,
      look: () => look,
      crop: (path, crop, look) async {
        crops.add((path, crop, look));
        return cropped;
      },
      compress: (path, size) async {
        compressions.add((path, size));
        return jpeg;
      },
    );

    void answer(XFile? file) => when(
      () => picker.pickImage(
        source: any(named: 'source'),
        requestFullMetadata: any(named: 'requestFullMetadata'),
      ),
    ).thenAnswer((_) async => file);

    test('takes a full-size camera photo, crops it, then compresses '
        'the crop', () async {
      answer(XFile('taken.jpg'));

      final bytes = await device().pick(
        PhotoSource.camera,
        PhotoSize.progressPhoto,
      );

      expect(bytes, jpeg);
      verify(
        () => picker.pickImage(
          source: ImageSource.camera,
          requestFullMetadata: false,
        ),
      ).called(1);
      expect(crops, [('taken.jpg', PhotoCrop.portrait, look)]);
      expect(compressions, [('cropped.jpg', PhotoSize.progressPhoto)]);
    });

    test('compresses an uncropped size as taken', () async {
      answer(XFile('plate.jpg'));

      final bytes = await device().pick(
        PhotoSource.camera,
        PhotoSize.foodPhoto,
      );

      expect(bytes, jpeg);
      expect(crops, isEmpty);
      expect(compressions, [('plate.jpg', PhotoSize.foodPhoto)]);
    });

    test('picks from the library, and a cancel is null', () async {
      answer(null);

      expect(
        await device().pick(PhotoSource.library, PhotoSize.avatar),
        isNull,
      );
      verify(
        () => picker.pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        ),
      ).called(1);
      expect(crops, isEmpty);
    });

    test('a cancelled crop is null', () async {
      answer(XFile('chosen.jpg'));
      cropped = null;

      expect(
        await device().pick(PhotoSource.library, PhotoSize.avatar),
        isNull,
      );
      expect(compressions, isEmpty);
    });

    test('crops in the platform look by default', () async {
      answer(XFile('chosen.jpg'));
      CropLook? used;

      await DevicePhotoPicker(
        picker: picker,
        crop: (_, _, look) async {
          used = look;
          return null;
        },
      ).pick(PhotoSource.library, PhotoSize.gymImage);

      expect(used?.title, isNull);
      expect(used?.toolbar, isNull);
    });

    test('defaults to the platform picker, cropper and compressor', () {
      expect(DevicePhotoPicker(), isA<PhotoPicker>());
    });

    void refuse(String code) => when(
      () => picker.pickImage(
        source: any(named: 'source'),
        requestFullMetadata: any(named: 'requestFullMetadata'),
      ),
    ).thenThrow(PlatformException(code: code));

    for (final code in ['camera_access_denied', 'photo_access_denied']) {
      test('a refusal ($code) is a PhotoAccessDeniedException', () {
        refuse(code);
        expect(
          device().pick(PhotoSource.camera, PhotoSize.foodPhoto),
          throwsA(isA<PhotoAccessDeniedException>()),
        );
      });
    }

    test('any other failure is passed on', () {
      refuse('no_available_camera');
      expect(
        device().pick(PhotoSource.camera, PhotoSize.foodPhoto),
        throwsA(isA<PlatformException>()),
      );
    });

    test('opens Settings with the opener it was given', () async {
      var opened = 0;
      await DevicePhotoPicker(
        picker: picker,
        openSettings: () async => opened++,
      ).openSettings();
      expect(opened, 1);
    });

    test("opens app_settings' page by default", () async {
      const channel = MethodChannel('com.spencerccf.app_settings/methods');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await DevicePhotoPicker(picker: picker).openSettings();
      expect(calls, hasLength(1));
    });
  });

  group('cropWithImageCropper', () {
    const channel = MethodChannel('plugins.hunghd.vn/image_cropper');
    late List<Map<Object?, Object?>> calls;
    late String photo;
    String? result;

    setUp(() async {
      calls = [];
      result = 'cropped.jpg';
      photo = await _photo(4, 3);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.arguments as Map<Object?, Object?>);
            return result;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
    });

    test('locks a fixed ratio, in the look it is given', () async {
      const look = CropLook(
        title: 'Crop Photo',
        done: 'Done',
        cancel: 'Cancel',
        toolbar: ui.Color(0xFFFFFFFF),
        onToolbar: ui.Color(0xFF000000),
        accent: ui.Color(0xFF000000),
        background: ui.Color(0xFFF2F2F7),
        brightness: ui.Brightness.light,
      );

      final path = await cropWithImageCropper(photo, PhotoCrop.wide, look);

      expect(path, 'cropped.jpg');
      final arguments = calls.single;
      expect(arguments['source_path'], photo);
      expect((arguments['ratio_x'], arguments['ratio_y']), (16.0, 9.0));
      expect(arguments['compress_format'], 'jpg');
      expect(arguments['compress_quality'], 100);
      expect(arguments['android.toolbar_title'], 'Crop Photo');
      expect(arguments['android.toolbar_color'], 0xFFFFFFFF.toSigned(32));
      expect(
        arguments['android.toolbar_widget_color'],
        0xFF000000.toSigned(32),
      );
      expect(arguments['android.status_bar_light'], isTrue);
      expect(arguments['android.lock_aspect_ratio'], isTrue);
      expect(arguments['android.crop_style'], 'rectangle');
      expect(arguments['ios.title'], 'Crop Photo');
      expect(arguments['ios.done_button_title'], 'Done');
      expect(arguments['ios.cancel_button_title'], 'Cancel');
      expect(arguments['ios.aspect_ratio_lock_enabled'], isTrue);
      expect(arguments['ios.aspect_ratio_picker_button_hidden'], isTrue);
    });

    test('shows a circle over a square profile picture', () async {
      await cropWithImageCropper(photo, PhotoCrop.circle, const CropLook());

      final arguments = calls.single;
      expect((arguments['ratio_x'], arguments['ratio_y']), (1.0, 1.0));
      expect(arguments['android.crop_style'], 'circle');
      expect(arguments['ios.crop_style'], 'circle');
      expect(arguments['android.status_bar_light'], isNull);
    });

    test('leaves a free crop unlocked, and a dark look dark', () async {
      final path = await cropWithImageCropper(
        photo,
        PhotoCrop.free,
        const CropLook(brightness: ui.Brightness.dark),
      );

      expect(path, 'cropped.jpg');
      final arguments = calls.single;
      expect(arguments['ratio_x'], isNull);
      expect(arguments['android.lock_aspect_ratio'], isFalse);
      expect(arguments['android.nav_bar_light'], isFalse);
      expect(arguments['ios.aspect_ratio_lock_enabled'], isFalse);
      expect(arguments['ios.reset_aspect_ratio_enabled'], isTrue);
    });

    test('a cancel is null', () async {
      result = null;
      expect(
        await cropWithImageCropper(photo, PhotoCrop.square, const CropLook()),
        isNull,
      );
    });
  });

  group('compressWithFlutterImageCompress', () {
    late FlutterImageCompressPlatform original;

    setUp(() => original = FlutterImageCompressPlatform.instance);
    tearDown(() => FlutterImageCompressPlatform.instance = original);

    _FakeCompress fake(Uint8List? result) =>
        FlutterImageCompressPlatform.instance = _FakeCompress(result);

    test('scales the longer side to the size, at its quality', () async {
      final compress = fake(jpeg);
      final landscape = await _photo(400, 300);
      final portrait = await _photo(300, 400);

      expect(
        await compressWithFlutterImageCompress(landscape, PhotoSize.foodPhoto),
        jpeg,
      );
      await compressWithFlutterImageCompress(portrait, PhotoSize.avatar);

      // flutter_image_compress scales until the shorter side is the box's,
      // so 1600 on the longer side is 1200 on the shorter.
      expect(compress.calls, [
        (landscape, 1200, 1200, 80),
        (portrait, 960, 960, 70),
      ]);
    });

    test('a photo it cannot compress is an error', () async {
      fake(null);
      final photo = await _photo(2, 2);
      await expectLater(
        compressWithFlutterImageCompress(photo, PhotoSize.foodImage),
        throwsStateError,
      );
    });
  });

  group('SamplePhotoPicker', () {
    test('returns the sample from either source', () async {
      final picker = SamplePhotoPicker(() async => jpeg);
      expect(await picker.pick(PhotoSource.camera, PhotoSize.avatar), jpeg);
      expect(
        await picker.pick(PhotoSource.library, PhotoSize.progressPhoto),
        jpeg,
      );
    });

    test('has no Settings to open', () async {
      await expectLater(
        SamplePhotoPicker(() async => jpeg).openSettings(),
        completes,
      );
    });
  });

  test('lists the native libraries on the licence page', () async {
    registerPhotoLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final packages = entries.expand((entry) => entry.packages).toSet();
    expect(
      packages,
      containsAll([
        'TOCropViewController',
        'SDWebImage',
        'SDWebImageWebPCoder',
        'libwebp',
        'uCrop',
        'OkHttp',
        'Apache Commons IO',
      ]),
    );
  });
}
