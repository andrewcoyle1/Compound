import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Where a photo comes from.
enum PhotoSource {
  /// Taken now.
  camera,

  /// Chosen from the photo library.
  library,
}

/// The longest side and JPEG quality a photo is stored at (Swift's
/// `uploadImage(maxDimension:quality:)`).
class const PhotoSize({
  /// The longest side, in pixels.
  required final int maxDimension,

  /// JPEG quality, 0 to 100.
  required final int quality,
}) {
  /// Creates a [PhotoSize].
  this;

  /// Profile pictures, food photos and thumbnails: 1280 at 0.7
  /// (`ImageUploadService.uploadImage(image:path:)`).
  static const standard = PhotoSize(maxDimension: 1280, quality: 70);

  /// Progress photos are compared side by side, so they keep more detail:
  /// 1600 at 0.8 (`ProgressPhotoManager`).
  static const progressPhoto = PhotoSize(maxDimension: 1600, quality: 80);

  /// A meal photo for the AI to read: 1600 at 0.8. Swift sends the camera's
  /// full image at 0.8, which a callable's 10 MB request limit can refuse
  /// once base64 has grown it by a third.
  static const foodPhoto = PhotoSize(maxDimension: 1600, quality: 80);
}

/// The camera or photo library may not be used: the person refused it, and
/// only Settings can undo that.
class PhotoAccessDeniedException implements Exception {
  /// Creates a [PhotoAccessDeniedException].
  const new();
}

/// Picks a photo, scaled and compressed to a [PhotoSize].
abstract interface class PhotoPicker {
  /// The photo as JPEG bytes, or null when the person cancels. Throws a
  /// [PhotoAccessDeniedException] when access was refused, and anything
  /// else when the source is unavailable or the photo cannot be read.
  Future<Uint8List?> pick(PhotoSource source, PhotoSize size);

  /// Opens the app's page in the system Settings, where a refused camera
  /// can be allowed again.
  Future<void> openSettings();
}

/// [PhotoPicker] on the device's camera and photo picker, through
/// image_picker, which scales the photo so its longest side is at most
/// `maxDimension` and re-encodes it as JPEG at `quality`.
class DevicePhotoPicker implements PhotoPicker {
  /// Creates a [DevicePhotoPicker] on `picker`, opening Settings with
  /// `openSettings` (app_settings when left out).
  new({ImagePicker? picker, Future<void> Function()? openSettings})
    : _picker = picker ?? ImagePicker(),
      _openSettings = openSettings ?? AppSettings.openAppSettings;

  final ImagePicker _picker;
  final Future<void> Function() _openSettings;

  /// image_picker's codes for a refused camera or library.
  static const _deniedCodes = {'camera_access_denied', 'photo_access_denied'};

  @override
  Future<void> openSettings() => _openSettings();

  @override
  Future<Uint8List?> pick(PhotoSource source, PhotoSize size) async {
    final XFile? file;
    try {
      file = await _pickImage(source, size);
    } on PlatformException catch (error) {
      if (_deniedCodes.contains(error.code)) {
        throw const PhotoAccessDeniedException();
      }
      rethrow;
    }
    return file == null ? null : await file.readAsBytes();
  }

  Future<XFile?> _pickImage(PhotoSource source, PhotoSize size) =>
      _picker.pickImage(
        source: switch (source) {
          PhotoSource.camera => ImageSource.camera,
          PhotoSource.library => ImageSource.gallery,
        },
        maxWidth: size.maxDimension.toDouble(),
        maxHeight: size.maxDimension.toDouble(),
        imageQuality: size.quality,
        // No photo-library permission prompt: the system picker returns only
        // the chosen photo, as Swift's PhotosPicker does.
        requestFullMetadata: false,
      );
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
