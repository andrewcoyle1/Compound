import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_repository/src/label_text_reader.dart';
import 'package:image_repository/src/photo_picker.dart';

/// The back camera, streaming its frames for [LabelTextReader.readFrame]
/// while its preview shows: the Label scanner's live reading.
abstract interface class LiveCamera {
  /// Opens the camera and hands each frame to `onFrame` until [close].
  /// Throws a [PhotoAccessDeniedException] when the camera was refused, and
  /// anything else when there is none or it cannot start.
  Future<void> open(void Function(LabelFrame frame) onFrame);

  /// Stops the frames and lets the camera go. Safe when it is not open.
  Future<void> close();

  /// Turns the torch on or off. Throws when the camera has none.
  Future<void> setTorch({required bool on});

  /// What the camera sees, filling its box. Only while open.
  Widget preview();
}

/// [LiveCamera] on the camera plugin: AVFoundation on iOS, CameraX on
/// Android, without sound, so the microphone is never asked for.
class DeviceLiveCamera implements LiveCamera {
  /// Creates a [DeviceLiveCamera].
  new();

  /// The plugin's codes for a refused or restricted camera.
  static const _deniedCodes = {
    'CameraAccessDenied',
    'CameraAccessDeniedWithoutPrompt',
    'CameraAccessRestricted',
  };

  CameraController? _controller;

  @override
  Future<void> open(void Function(LabelFrame frame) onFrame) async {
    try {
      final cameras = await availableCameras();
      final controller = _controller = CameraController(
        cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        ),
        // 1080p: small print stays legible, and Vision's accurate reading
        // of a frame takes well under the half second between reads.
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      await controller.startImageStream(
        (image) => onFrame(
          labelFrame(
            image,
            sensorOrientation: controller.description.sensorOrientation,
            deviceOrientation: controller.value.deviceOrientation,
          ),
        ),
      );
    } on Object catch (error) {
      await close();
      if (error is CameraException && _deniedCodes.contains(error.code)) {
        throw const PhotoAccessDeniedException();
      }
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  @override
  Future<void> setTorch({required bool on}) async =>
      await _controller?.setFlashMode(on ? FlashMode.torch : FlashMode.off);

  @override
  Widget preview() => switch (_controller) {
    final controller? => FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        // The preview's size is landscape; upright, it is the other way.
        width: controller.value.previewSize?.height ?? 0,
        height: controller.value.previewSize?.width ?? 0,
        child: CameraPreview(controller),
      ),
    ),
    null => const SizedBox.expand(),
  };
}

/// [image] as a [LabelFrame]: its first plane, which holds the whole frame
/// in BGRA and in NV21. iOS frames already stand as the device does
/// (camera_avfoundation turns its video connection); Android frames are as
/// the sensor sees them, so they turn by its mounting, [sensorOrientation],
/// less the device's turn.
@visibleForTesting
LabelFrame labelFrame(
  CameraImage image, {
  required int sensorOrientation,
  required DeviceOrientation deviceOrientation,
}) {
  final plane = image.planes.first;
  final deviceTurn = switch (deviceOrientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };
  return LabelFrame(
    bytes: plane.bytes,
    width: image.width,
    height: image.height,
    bytesPerRow: plane.bytesPerRow,
    rotation: defaultTargetPlatform == TargetPlatform.android
        ? (sensorOrientation - deviceTurn + 360) % 360
        : 0,
  );
}

/// [LiveCamera] for the staging flavor, which has no camera (simulators):
/// the preview is a bundled photo of a label, sent as a frame four times a
/// second. Its bytes are never decoded: [SampleLabelTextReader] reads every
/// frame as its sample text.
class SampleLiveCamera implements LiveCamera {
  /// Creates a [SampleLiveCamera] showing what `load` reads, the bundled
  /// [labelAsset] when left out.
  new({Future<Uint8List> Function()? load}) : _load = load ?? _loadLabel;

  /// The bundled label photo, drawn for Compound in Nunito (OFL).
  static const labelAsset = 'packages/image_repository/assets/sample_label.jpg';

  static Future<Uint8List> _loadLabel() async =>
      (await rootBundle.load(labelAsset)).buffer.asUint8List();

  final Future<Uint8List> Function() _load;
  Uint8List? _photo;
  Timer? _timer;

  @override
  Future<void> open(void Function(LabelFrame frame) onFrame) async {
    final photo = _photo = await _load();
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => onFrame(
        LabelFrame(
          bytes: photo,
          width: 1440,
          height: 1080,
          bytesPerRow: 1440 * 4,
          rotation: 0,
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
  }

  /// Staging's torch does nothing.
  @override
  Future<void> setTorch({required bool on}) async {}

  @override
  Widget preview() => switch (_photo) {
    final photo? => Image.memory(
      photo,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
    ),
    null => const SizedBox.expand(),
  };
}
