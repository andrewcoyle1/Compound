import 'dart:typed_data';

/// Stores images and hands back the URL each can be shown from (Swift
/// `ImageUploadManager`).
abstract interface class ImageRepository {
  /// Stores [jpeg] at [path] as `image/jpeg` and returns its download URL.
  ///
  /// The paths are Swift's, so both apps read each other's uploads:
  /// `users/{uid}/profile` for the profile photo (`UserManager`) and
  /// `users/{uid}/progress_photos/{id}.jpg` for a progress photo
  /// (`ProgressPhotoModel.storagePathFor`). An upload needs the server, so
  /// it fails, rather than waits, when the device is offline.
  Future<String> upload(Uint8List jpeg, String path);

  /// Removes the image at [path].
  Future<void> delete(String path);
}
