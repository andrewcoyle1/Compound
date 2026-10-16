import 'dart:typed_data';

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
}

/// Picks a photo, scaled and compressed to a [PhotoSize].
abstract interface class PhotoPicker {
  /// The photo as JPEG bytes, or null when the person cancels. Throws when
  /// the source is unavailable or the photo cannot be read.
  Future<Uint8List?> pick(PhotoSource source, PhotoSize size);
}

/// [PhotoPicker] on the device's camera and photo picker, through
/// image_picker, which scales the photo so its longest side is at most
/// `maxDimension` and re-encodes it as JPEG at `quality`.
class DevicePhotoPicker implements PhotoPicker {
  /// Creates a [DevicePhotoPicker] on `picker`.
  new({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pick(PhotoSource source, PhotoSize size) async {
    final file = await _picker.pickImage(
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
    return file == null ? null : await file.readAsBytes();
  }
}

/// [PhotoPicker] for the staging flavor: every pick, from either source,
/// returns the bundled sample its loader reads.
class SamplePhotoPicker implements PhotoPicker {
  /// Creates a [SamplePhotoPicker] returning what `load` reads.
  new(Future<Uint8List> Function() load) : _load = load;

  final Future<Uint8List> Function() _load;

  @override
  Future<Uint8List?> pick(PhotoSource source, PhotoSize size) => _load();
}
