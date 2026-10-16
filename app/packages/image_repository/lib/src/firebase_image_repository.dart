import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_repository/src/image_repository.dart';

/// [ImageRepository] on Firebase Storage (Swift
/// `FirebaseImageUploadService`).
class FirebaseImageRepository implements ImageRepository {
  /// Creates a [FirebaseImageRepository] on `storage`.
  ///
  /// Offline, Storage retries an upload for ten minutes by default behind
  /// whatever spinner started it; Swift refuses up front
  /// (`NetworkMonitor.requireOnline`). Here a failed upload stops retrying
  /// after [maxUploadRetryTime] and fails with Storage's
  /// `retry-limit-exceeded`.
  new({
    required this._storage,
    this.maxUploadRetryTime = const Duration(seconds: 15),
  });

  final FirebaseStorage _storage;

  /// How long a failing upload keeps retrying.
  final Duration maxUploadRetryTime;

  @override
  Future<String> upload(Uint8List jpeg, String path) async {
    _storage.setMaxUploadRetryTime(maxUploadRetryTime);
    final reference = _storage.ref(path);
    await reference.putData(jpeg, SettableMetadata(contentType: 'image/jpeg'));
    return await reference.getDownloadURL();
  }

  @override
  Future<void> delete(String path) => _storage.ref(path).delete();
}
