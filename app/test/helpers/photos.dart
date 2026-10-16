import 'dart:typed_data';

import 'package:image_repository/image_repository.dart';

/// A picker that returns [photo] (null for a cancel) or throws [error],
/// remembering each pick and each time Settings is opened.
class FakePhotoPicker implements PhotoPicker {
  Uint8List? photo = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
  Exception? error;
  final picks = <(PhotoSource, PhotoSize)>[];
  int settingsOpened = 0;

  @override
  Future<Uint8List?> pick(PhotoSource source, PhotoSize size) async {
    picks.add((source, size));
    if (error case final error?) throw error;
    return photo;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

/// Storage that refuses every upload, as offline after its retries.
class FailingImageRepository extends InMemoryImageRepository {
  @override
  Future<String> upload(Uint8List jpeg, String path) =>
      Future.error(Exception('retry-limit-exceeded'));
}
