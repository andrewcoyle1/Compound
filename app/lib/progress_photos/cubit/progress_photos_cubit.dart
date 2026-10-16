import 'dart:async';
import 'dart:typed_data';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart' show AppWeightUnit;
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/document_id.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:image_repository/image_repository.dart';

part 'progress_photos_state.dart';

/// Progress Photos (Swift `ProgressPhotosPresenter` and
/// `ProgressPhotoManager`): the user's photos by day, added from the camera
/// for a chosen pose or from the library (then asked which pose), two
/// chosen to compare, and one deleted.
///
/// An add uploads the image, then saves the document pointing at it, and
/// removes the image again if the save cannot start. A delete removes the
/// document first, so a photo never shows without its image, then the
/// image, whose failure is ignored as Swift ignores it.
class ProgressPhotosCubit extends Cubit<ProgressPhotosState> {
  new({
    required this._uid,
    required this._body,
    required this._images,
    required this._picker,
    required this._analytics,
    AppWeightUnit weightUnit = AppWeightUnit.kilograms,
    this._clock = DateTime.now,
  }) : super(ProgressPhotosState(weightUnit: weightUnit)) {
    _analytics.appear(_screen);
    _subscription = _body
        .watchProgressPhotos(_uid)
        .listen(
          (photos) => emit(
            state.copyWith(
              photos: photos,
              loaded: true,
              // A photo deleted elsewhere is no longer chosen.
              selectedIds: [
                for (final id in state.selectedIds)
                  if (photos.any((photo) => photo.id == id)) id,
              ],
            ),
          ),
          onError: (Object _) => emit(state.copyWith(loaded: true)),
        );
  }

  static const _screen = 'ProgressPhotosView';

  final String _uid;
  final BodyRepository _body;
  final ImageRepository _images;
  final PhotoPicker _picker;
  final AnalyticsRepository _analytics;
  final DateTime Function() _clock;
  late final StreamSubscription<List<ProgressPhotoModel>> _subscription;

  /// One of the camera items: the pose is chosen before the shutter, so the
  /// photo saves as soon as it is taken.
  Future<void> cameraPressed(ProgressPhotoPose pose) async {
    final image = await _pick(PhotoSource.camera);
    if (image != null) await _add(image, pose);
  }

  /// Choose from Library: the pose is asked once the photo is in hand.
  Future<void> libraryPressed() async {
    final image = await _pick(PhotoSource.library);
    if (image != null) emit(state.copyWith(pendingImage: () => image));
  }

  /// The pose for the library photo waiting.
  Future<void> poseSelected(ProgressPhotoPose pose) async {
    final image = state.pendingImage;
    if (image == null) return;
    emit(state.copyWith(pendingImage: () => null));
    await _add(image, pose);
  }

  /// The pose question was dismissed; the photo is dropped.
  void poseCancelled() => emit(state.copyWith(pendingImage: () => null));

  /// Toggles [photo]. A third choice drops the earliest, so the two chosen
  /// are always the latest two tapped.
  void photoPressed(ProgressPhotoModel photo) {
    final ids = [...state.selectedIds];
    if (!ids.remove(photo.id)) {
      ids.add(photo.id);
      if (ids.length > 2) ids.removeAt(0);
    }
    emit(state.copyWith(selectedIds: ids));
  }

  /// `ProgressPhotosView_Compare`; the view opens the pair.
  void comparePressed() => _analytics.analytic('${_screen}_Compare');

  /// Deletes [photo], once confirmed.
  Future<void> deleteConfirmed(ProgressPhotoModel photo) async {
    emit(
      state.copyWith(
        selectedIds: [
          for (final id in state.selectedIds)
            if (id != photo.id) id,
        ],
      ),
    );
    _analytics.analytic('${_screen}_Delete_Start');
    try {
      await _body.deleteProgressPhoto(_uid, photo.id);
      _analytics.analytic('${_screen}_Delete_Success');
    } on Object catch (error) {
      _analytics.severe('${_screen}_Delete_Fail', error);
      emit(state.copyWith(deleteFailures: state.deleteFailures + 1));
      return;
    }
    // An unreferenced image is harmless, and not worth failing over.
    try {
      await _images.delete(photo.storagePath);
    } on Object catch (_) {}
  }

  Future<Uint8List?> _pick(PhotoSource source) async {
    try {
      return await _picker.pick(source, PhotoSize.progressPhoto);
    } on Object catch (error) {
      _analytics.severe('${_screen}_LoadLibraryPhoto_Fail', error);
      emit(state.copyWith(loadFailures: state.loadFailures + 1));
      return null;
    }
  }

  Future<void> _add(Uint8List image, ProgressPhotoPose pose) async {
    final parameters = {'pose': pose.value};
    emit(state.copyWith(isUploading: true));
    _analytics.analytic('${_screen}_Add_Start', parameters);
    try {
      final id = newDocumentId();
      final path = ProgressPhotoModel.storagePathFor(_uid, id);
      final url = await _images.upload(image, path);
      final photo = ProgressPhotoModel(
        id: id,
        authorId: _uid,
        date: _clock(),
        pose: pose,
        storagePath: path,
        imageUrl: url,
        weightKg: await _latestWeightKg(),
      );
      try {
        await _body.saveProgressPhoto(photo);
      } on Object {
        // Not left orphaned in Storage.
        await _images.delete(path).catchError((Object _) {});
        rethrow;
      }
      _analytics.analytic('${_screen}_Add_Success', parameters);
      emit(state.copyWith(isUploading: false));
    } on Object catch (error) {
      _analytics.severe('${_screen}_Add_Fail', error);
      emit(
        state.copyWith(isUploading: false, addFailures: state.addFailures + 1),
      );
    }
  }

  /// The most recent logged scale weight (`addProgressPhoto`); none when
  /// there is none or it cannot be read.
  Future<double?> _latestWeightKg() async {
    try {
      final entries = await _body.watchMeasurements(_uid).first;
      return entries.map((entry) => entry.weightKg).nonNulls.lastOrNull;
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    _analytics.disappear(_screen);
    await _subscription.cancel();
    await super.close();
  }
}
