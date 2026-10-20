part of 'progress_photos_cubit.dart';

/// The signed-in user's progress photos and what is chosen among them.
final class const ProgressPhotosState({
  /// Newest first.
  final List<ProgressPhotoModel> photos = const [],

  /// Whether the photos have arrived.
  final bool loaded = false,

  /// The ids chosen, in the order they were tapped; at most two.
  final List<String> selectedIds = const [],

  /// A library photo waiting for its pose; the view asks which.
  final Uint8List? pendingImage,

  /// Whether a photo is uploading.
  final bool isUploading = false,

  /// How the weights in the captions are shown.
  final AppWeightUnit weightUnit = AppWeightUnit.kilograms,

  /// How many photos could not be read from the camera or library, so each
  /// says so.
  final int loadFailures = 0,

  /// How many adds have failed, so each says so.
  final int addFailures = 0,

  /// How many deletes have failed, so each says so.
  final int deleteFailures = 0,
}) extends Equatable {
  /// One section per day, newest first, each day's photos newest first
  /// (`ProgressPhotosPresenter.sections`).
  List<(DateTime, List<ProgressPhotoModel>)> get sections {
    final byDay = <DateTime, List<ProgressPhotoModel>>{};
    for (final photo in photos) {
      final local = photo.date.toLocal();
      byDay
          .putIfAbsent(DateTime(local.year, local.month, local.day), () => [])
          .add(photo);
    }
    return [for (final entry in byDay.entries) (entry.key, entry.value)];
  }

  /// Whether [photo] is chosen.
  bool isSelected(ProgressPhotoModel photo) => selectedIds.contains(photo.id);

  /// The two chosen photos, older first whichever order they were tapped
  /// in (`onComparePressed`); null unless exactly two are chosen.
  (ProgressPhotoModel, ProgressPhotoModel)? get comparePair {
    final chosen = [
      for (final photo in photos)
        if (selectedIds.contains(photo.id)) photo,
    ]..sort((a, b) => a.date.compareTo(b.date));
    return chosen.length == 2 ? (chosen[0], chosen[1]) : null;
  }

  /// The one chosen photo, which the toolbar's Delete removes
  /// (`selectedPhotoForDelete`).
  ProgressPhotoModel? get selectedForDelete => selectedIds.length == 1
      ? photos.where((photo) => photo.id == selectedIds.single).firstOrNull
      : null;

  ProgressPhotosState copyWith({
    List<ProgressPhotoModel>? photos,
    bool? loaded,
    List<String>? selectedIds,
    Uint8List? Function()? pendingImage,
    bool? isUploading,
    AppWeightUnit? weightUnit,
    int? loadFailures,
    int? addFailures,
    int? deleteFailures,
  }) => ProgressPhotosState(
    photos: photos ?? this.photos,
    loaded: loaded ?? this.loaded,
    selectedIds: selectedIds ?? this.selectedIds,
    pendingImage: pendingImage == null ? this.pendingImage : pendingImage(),
    isUploading: isUploading ?? this.isUploading,
    weightUnit: weightUnit ?? this.weightUnit,
    loadFailures: loadFailures ?? this.loadFailures,
    addFailures: addFailures ?? this.addFailures,
    deleteFailures: deleteFailures ?? this.deleteFailures,
  );

  @override
  List<Object?> get props => [
    photos,
    loaded,
    selectedIds,
    pendingImage,
    isUploading,
    weightUnit,
    loadFailures,
    addFailures,
    deleteFailures,
  ];
}
