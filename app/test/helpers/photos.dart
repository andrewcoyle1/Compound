import 'dart:async';
import 'dart:typed_data';

import 'package:app_ui/app_ui.dart';

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

/// A live camera whose frames the test sends with [send]; [error] makes
/// opening fail, [torchError] lighting the torch. It remembers how often it
/// opened and closed, and the torch's last setting.
class FakeLiveCamera implements LiveCamera {
  Exception? error;
  Exception? torchError;

  /// When set, opening waits for it.
  Completer<void>? openGate;
  int opened = 0;
  int closed = 0;
  bool? torch;
  void Function(LabelFrame frame)? _onFrame;

  /// Whether frames are flowing.
  bool get isOpen => _onFrame != null;

  /// One frame, if the camera is open.
  void send([LabelFrame? frame]) => _onFrame?.call(
    frame ??
        LabelFrame(
          bytes: Uint8List(4),
          width: 1,
          height: 1,
          bytesPerRow: 4,
          rotation: 0,
        ),
  );

  @override
  Future<void> open(void Function(LabelFrame frame) onFrame) async {
    opened++;
    await openGate?.future;
    if (error case final error?) throw error;
    _onFrame = onFrame;
  }

  @override
  Future<void> close() async {
    closed++;
    _onFrame = null;
  }

  @override
  Future<void> setTorch({required bool on}) async {
    if (torchError case final error?) throw error;
    torch = on;
  }

  @override
  Widget preview() => const SizedBox.expand(key: Key('FakeLiveCamera.preview'));
}
