import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Where a photo comes from.
enum PhotoSource {
  /// Taken now.
  camera,

  /// Chosen from the photo library.
  library,
}

/// How a photo is framed before it is stored: its width to height, or none
/// for a frame the person draws freely.
enum PhotoCrop(final int? ratioX, final int? ratioY) {
  /// Not cropped: stored as taken.
  none(null, null),

  /// Any rectangle the person draws.
  free(null, null),

  /// A square.
  square(1, 1),

  /// A square framed by a circle, as a profile picture is shown.
  circle(1, 1),

  /// 3:4 upright, so progress photos line up side by side.
  portrait(3, 4),

  /// 16:9, a recipe's header picture.
  wide(16, 9),
}

/// How each kind of photo is cropped, and the longest side and JPEG quality
/// it is stored at (Swift's `uploadImage(maxDimension:quality:)`).
class const PhotoSize({
  /// The longest side, in pixels.
  required final int maxDimension,

  /// JPEG quality, 0 to 100.
  required final int quality,

  /// How the person frames it first.
  required final PhotoCrop crop,
}) {
  /// Creates a [PhotoSize].
  this;

  /// A profile picture: square in a circle, at Swift's 1280 and 0.7
  /// (`ImageUploadService.uploadImage(image:path:)`), as every size below
  /// is unless it says otherwise.
  static const avatar = PhotoSize(
    maxDimension: 1280,
    quality: 70,
    crop: PhotoCrop.circle,
  );

  /// A custom food's picture, shown as a square thumbnail.
  static const foodImage = PhotoSize(
    maxDimension: 1280,
    quality: 70,
    crop: PhotoCrop.square,
  );

  /// A recipe's 16:9 header picture.
  static const recipeImage = PhotoSize(
    maxDimension: 1280,
    quality: 70,
    crop: PhotoCrop.wide,
  );

  /// A gym's picture, framed freely.
  static const gymImage = PhotoSize(
    maxDimension: 1280,
    quality: 70,
    crop: PhotoCrop.free,
  );

  /// Progress photos are compared side by side, so they are 3:4 and keep
  /// more detail: 1600 at 0.8 (`ProgressPhotoManager`).
  static const progressPhoto = PhotoSize(
    maxDimension: 1600,
    quality: 80,
    crop: PhotoCrop.portrait,
  );

  /// A meal photo for the AI to read: uncropped, so the whole plate counts,
  /// at 1600 and 0.8. Swift sends the camera's full image at 0.8, which a
  /// callable's 10 MB request limit can refuse once base64 has grown it by
  /// a third.
  static const foodPhoto = PhotoSize(
    maxDimension: 1600,
    quality: 80,
    crop: PhotoCrop.none,
  );

  /// A nutrition label for the AI to read, cropped freely to the label, at
  /// a food photo's 1600 and 0.8.
  static const labelPhoto = PhotoSize(
    maxDimension: 1600,
    quality: 80,
    crop: PhotoCrop.free,
  );
}

/// The crop screen's words and colours, from the app's theme and language.
/// Whatever is left out keeps the platform's own.
class const CropLook({
  /// The screen's title.
  final String? title,

  /// The confirm button (iOS).
  final String? done,

  /// The cancel button (iOS).
  final String? cancel,

  /// The toolbar's fill (Android).
  final ui.Color? toolbar,

  /// The toolbar's title and buttons (Android).
  final ui.Color? onToolbar,

  /// The selected controls (Android).
  final ui.Color? accent,

  /// Behind the photo (Android).
  final ui.Color? background,

  /// Light or dark, for the system bars' icons (Android).
  final ui.Brightness? brightness,
}) {
  /// Creates a [CropLook].
  this;
}

/// Shows the crop screen for the photo at a path, framed as `crop` and
/// styled by `look`; the cropped photo's path, or null when the person
/// cancels.
typedef PhotoCropper = Future<String?> Function(
  String path,
  PhotoCrop crop,
  CropLook look,
);

/// Scales the photo at a path so its longest side is at most the size's
/// `maxDimension`, and encodes it as JPEG at its `quality`.
typedef PhotoCompressor = Future<Uint8List> Function(
  String path,
  PhotoSize size,
);

/// The camera or photo library may not be used: the person refused it, and
/// only Settings can undo that.
class PhotoAccessDeniedException implements Exception {
  /// Creates a [PhotoAccessDeniedException].
  const new();
}

/// Picks a photo, cropped, scaled and compressed to a [PhotoSize].
abstract interface class PhotoPicker {
  /// The photo as JPEG bytes, or null when the person cancels the picker or
  /// the crop. Throws a [PhotoAccessDeniedException] when access was
  /// refused, and anything else when the source is unavailable or the photo
  /// cannot be read.
  Future<Uint8List?> pick(PhotoSource source, PhotoSize size);

  /// Opens the app's page in the system Settings, where a refused camera
  /// can be allowed again.
  Future<void> openSettings();
}

/// [PhotoPicker] on the device's camera and photo picker (image_picker), at
/// full size; then the crop screen (image_cropper: uCrop on Android,
/// TOCropViewController on iOS) unless the size has [PhotoCrop.none]; then
/// flutter_image_compress, the only step that scales and encodes.
class DevicePhotoPicker implements PhotoPicker {
  /// Creates a [DevicePhotoPicker] on `picker`, opening Settings with
  /// `openSettings` (app_settings when left out). The crop screen looks as
  /// `look` says when it opens (the platform's own look when left out);
  /// `crop` and `compress` replace image_cropper and flutter_image_compress
  /// in tests.
  new({
    ImagePicker? picker,
    Future<void> Function()? openSettings,
    CropLook Function()? look,
    PhotoCropper? crop,
    PhotoCompressor? compress,
  }) : _picker = picker ?? ImagePicker(),
       _openSettings = openSettings ?? AppSettings.openAppSettings,
       _look = look ?? _platformLook,
       _crop = crop ?? cropWithImageCropper,
       _compress = compress ?? compressWithFlutterImageCompress;

  final ImagePicker _picker;
  final Future<void> Function() _openSettings;
  final CropLook Function() _look;
  final PhotoCropper _crop;
  final PhotoCompressor _compress;

  static CropLook _platformLook() => const CropLook();

  /// image_picker's codes for a refused camera or library.
  static const _deniedCodes = {'camera_access_denied', 'photo_access_denied'};

  @override
  Future<void> openSettings() => _openSettings();

  @override
  Future<Uint8List?> pick(PhotoSource source, PhotoSize size) async {
    final XFile? file;
    try {
      file = await _pickImage(source);
    } on PlatformException catch (error) {
      if (_deniedCodes.contains(error.code)) {
        throw const PhotoAccessDeniedException();
      }
      rethrow;
    }
    if (file == null) return null;
    var path = file.path;
    if (size.crop != PhotoCrop.none) {
      final cropped = await _crop(path, size.crop, _look());
      if (cropped == null) return null;
      path = cropped;
    }
    return await _compress(path, size);
  }

  Future<XFile?> _pickImage(PhotoSource source) => _picker.pickImage(
    source: switch (source) {
      PhotoSource.camera => ImageSource.camera,
      PhotoSource.library => ImageSource.gallery,
    },
    // No photo-library permission prompt: the system picker returns only
    // the chosen photo, as Swift's PhotosPicker does.
    requestFullMetadata: false,
  );
}

/// [PhotoCropper] on image_cropper. A fixed ratio is locked; a free crop
/// may be any shape. The result is a near-lossless JPEG, left for
/// [compressWithFlutterImageCompress] to scale and encode.
Future<String?> cropWithImageCropper(
  String path,
  PhotoCrop crop,
  CropLook look,
) async {
  final x = crop.ratioX;
  final y = crop.ratioY;
  final locked = x != null && y != null;
  final style = crop == PhotoCrop.circle
      ? CropStyle.circle
      : CropStyle.rectangle;
  final light = look.brightness == null
      ? null
      : look.brightness == ui.Brightness.light;
  final cropped = await ImageCropper().cropImage(
    sourcePath: path,
    aspectRatio: locked
        ? CropAspectRatio(ratioX: x.toDouble(), ratioY: y.toDouble())
        : null,
    compressQuality: 100,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: look.title,
        toolbarColor: look.toolbar,
        toolbarWidgetColor: look.onToolbar,
        activeControlsWidgetColor: look.accent,
        backgroundColor: look.background,
        statusBarLight: light,
        navBarLight: light,
        lockAspectRatio: locked,
        cropStyle: style,
      ),
      IOSUiSettings(
        title: look.title,
        doneButtonTitle: look.done,
        cancelButtonTitle: look.cancel,
        aspectRatioLockEnabled: locked,
        resetAspectRatioEnabled: !locked,
        aspectRatioPickerButtonHidden: locked,
        cropStyle: style,
      ),
    ],
  );
  return cropped?.path;
}

/// [PhotoCompressor] on flutter_image_compress, which scales a photo until
/// its shorter side reaches a box's: so the box is the shorter side that
/// puts the longer one at `maxDimension`. A photo already smaller is only
/// re-encoded. EXIF is dropped and the photo turned upright.
Future<Uint8List> compressWithFlutterImageCompress(
  String path,
  PhotoSize size,
) async {
  final buffer = await ui.ImmutableBuffer.fromFilePath(path);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final (width, height) = (descriptor.width, descriptor.height);
  descriptor.dispose();
  buffer.dispose();
  // The ratio of the sides, unlike which one is the width, survives the
  // EXIF rotation applied while compressing.
  final box =
      size.maxDimension * math.min(width, height) ~/ math.max(width, height);
  final bytes = await FlutterImageCompress.compressWithFile(
    path,
    minWidth: box,
    minHeight: box,
    quality: size.quality,
  );
  return bytes ?? (throw StateError('The photo could not be compressed.'));
}

/// [PhotoPicker] for the staging flavor: every pick, from either source,
/// returns the bundled sample its loader reads.
class SamplePhotoPicker implements PhotoPicker {
  /// Creates a [SamplePhotoPicker] returning what `load` reads.
  new(Future<Uint8List> Function() load) : _load = load;

  final Future<Uint8List> Function() _load;

  @override
  Future<Uint8List?> pick(PhotoSource source, PhotoSize size) => _load();

  /// Staging has no Settings to open.
  @override
  Future<void> openSettings() async {}
}

/// Lists the native libraries the crop screen, compressor and live camera
/// bundle (TOCropViewController and SDWebImage on iOS, uCrop and CameraX on
/// Android) on the app's licence page, which finds only Dart packages
/// itself. Call once at startup.
void registerPhotoLicenses() => LicenseRegistry.addLicense(() async* {
  for (final (packages, file) in const [
    (['TOCropViewController'], 'TOCropViewController.txt'),
    (['SDWebImage'], 'SDWebImage.txt'),
    (['SDWebImageWebPCoder'], 'SDWebImageWebPCoder.txt'),
    (['libwebp'], 'libwebp.txt'),
    (['uCrop', 'OkHttp', 'Apache Commons IO', 'CameraX'], 'Apache-2.0.txt'),
  ]) {
    yield LicenseEntryWithLineBreaks(
      packages,
      await rootBundle.loadString(
        'packages/image_repository/assets/licenses/$file',
      ),
    );
  }
});
