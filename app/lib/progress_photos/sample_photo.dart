import 'package:flutter/services.dart';
import 'package:image_repository/image_repository.dart';

/// The picture the staging flavor's camera and library return: a bundled
/// exercise picture, as Swift's mock photos are.
const samplePhotoAsset = 'assets/exercises/BarbellSquat.webp';

/// The staging flavor's camera and library, returning [samplePhotoAsset].
PhotoPicker samplePhotoPicker() => SamplePhotoPicker(
  () async => (await rootBundle.load(samplePhotoAsset)).buffer.asUint8List(),
);
