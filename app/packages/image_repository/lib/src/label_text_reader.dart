import 'package:flutter/services.dart';
import 'package:image_repository/src/live_camera.dart';

/// Reads the text printed in a photo, on the device: a nutrition label for
/// the Label scanner (Swift `BarcodeScanner`'s `.text()` recognition).
abstract interface class LabelTextReader {
  /// The text in [jpeg], one line per printed line; empty when none was
  /// found. Throws when the photo cannot be read.
  Future<String> read(Uint8List jpeg);

  /// The text in one frame of a [LiveCamera], as [read] gives it.
  Future<String> readFrame(LabelFrame frame);
}

/// One frame of a [LiveCamera]: BGRA on iOS, NV21 on Android, as the
/// platform code reads it.
class const LabelFrame({
  /// The pixels.
  required final Uint8List bytes,

  /// The width, in pixels.
  required final int width,

  /// The height, in pixels.
  required final int height,

  /// The bytes in one row of [bytes], padding included.
  required final int bytesPerRow,

  /// How far the frame turns clockwise, in degrees (0, 90, 180 or 270), to
  /// stand upright.
  required final int rotation,
}) {
  /// Creates a [LabelFrame].
  this;
}

/// [LabelTextReader] on the app's own platform code: Apple Vision on iOS
/// (`AppDelegate.swift`), ML Kit's bundled Latin model on Android
/// (`MainActivity.kt`). Nothing leaves the device.
class PlatformLabelTextReader implements LabelTextReader {
  /// Creates a [PlatformLabelTextReader] on [channel].
  const new({this.channel = const MethodChannel(channelName)});

  /// The app's channel name.
  static const channelName = 'com.andrewcoyle.compound/label_text';

  /// The channel the platform code answers on.
  final MethodChannel channel;

  @override
  Future<String> read(Uint8List jpeg) async =>
      (await channel.invokeMethod<String>('read', jpeg))?.trim() ?? '';

  @override
  Future<String> readFrame(LabelFrame frame) async =>
      (await channel.invokeMethod<String>('readFrame', {
        'bytes': frame.bytes,
        'width': frame.width,
        'height': frame.height,
        'bytesPerRow': frame.bytesPerRow,
        'rotation': frame.rotation,
      }))?.trim() ??
      '';
}

/// [LabelTextReader] for the staging flavor and tests: every photo reads
/// as [text].
class SampleLabelTextReader implements LabelTextReader {
  /// Creates a [SampleLabelTextReader] reading [text].
  const new({this.text = sampleLabel});

  /// A typical label, as staging's canned `nutritionLabelAnalyze` expects.
  static const sampleLabel =
      'Nutrition Facts\n'
      'Per 100 g\n'
      'Energy 1550 kJ / 370 kcal\n'
      'Fat 6.5 g\n'
      'of which saturates 1.2 g\n'
      'Carbohydrate 60 g\n'
      'of which sugars 1.1 g\n'
      'Fibre 9.4 g\n'
      'Protein 13 g\n'
      'Salt 0.02 g';

  /// What every photo reads as.
  final String text;

  @override
  Future<String> read(Uint8List jpeg) async => text;

  @override
  Future<String> readFrame(LabelFrame frame) async => text;
}
