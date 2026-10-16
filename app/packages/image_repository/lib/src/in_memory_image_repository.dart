import 'dart:typed_data';

import 'package:image_repository/src/image_repository.dart';

/// [ImageRepository] in memory, for the staging flavor and tests (Swift
/// `MockImageUploadService`). An upload's URL is a `data:` URI holding the
/// image, so the screens show what was "uploaded" with no server.
class InMemoryImageRepository implements ImageRepository {
  /// The images stored, by path.
  final images = <String, Uint8List>{};

  @override
  Future<String> upload(Uint8List jpeg, String path) async {
    images[path] = jpeg;
    return Uri.dataFromBytes(jpeg, mimeType: 'image/jpeg').toString();
  }

  @override
  Future<void> delete(String path) async {
    images.remove(path);
  }
}
