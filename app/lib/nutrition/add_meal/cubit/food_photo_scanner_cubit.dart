import 'dart:typed_data';

import 'package:ai_repository/ai_repository.dart';
import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:image_repository/image_repository.dart';

/// Where an AI estimate has got to.
enum EstimateStatus {
  /// Nothing asked yet.
  idle,

  /// Waiting for the model.
  analysing,

  /// The model answered, perhaps with no foods.
  analysed,

  /// The call failed or the answer could not be read.
  failed,
}

/// Whether the AI tab may use the camera (Swift `CameraAccess`, less
/// `notDetermined`: the system asks when the camera is first opened).
enum CameraState {
  /// Usable, as far as is known.
  ready,

  /// Refused; only Settings can undo it.
  denied,

  /// No camera, or it failed to open.
  unavailable,
}

/// The picker's AI tab (Swift `FoodPhotoScannerPresenter`): a photo of a
/// meal is sent to `foodAnalyze`, and the foods it finds can be added all
/// at once or one at a time through the amount sheet.
class FoodPhotoScannerCubit extends Cubit<FoodPhotoScannerState> {
  new({required this._ai, required this._picker, required this._analytics})
    : super(const FoodPhotoScannerState());

  final AiRepository _ai;
  final PhotoPicker _picker;
  final AnalyticsRepository _analytics;

  /// Takes a photo and analyses it. A cancel leaves the tab as it was.
  Future<void> takePhoto() async {
    final Uint8List? photo;
    try {
      photo = await _picker.pick(PhotoSource.camera, PhotoSize.foodPhoto);
    } on PhotoAccessDeniedException {
      _track('FoodPhotoScanner_CameraDenied');
      if (!isClosed) emit(state.copyWith(camera: CameraState.denied));
      return;
    } on Object {
      if (!isClosed) emit(state.copyWith(camera: CameraState.unavailable));
      return;
    }
    if (photo == null || isClosed) return;
    await analyse(photo);
  }

  /// Sends [photo] to the model, forgetting the last shot's outcome.
  Future<void> analyse(Uint8List photo) async {
    emit(FoodPhotoScannerState(photo: photo, status: EstimateStatus.analysing));
    _track('FoodPhotoScanner_Capture');
    try {
      final items = await _ai.analyzeFood(photo);
      _track('FoodPhotoScannerView_Analyse_Success', {
        'item_count': items.length,
      });
      if (!isClosed) {
        emit(state.copyWith(status: EstimateStatus.analysed, items: items));
      }
    } on Object catch (error) {
      _track('FoodPhotoScanner_Error', {'error': '$error'}, LogType.severe);
      if (!isClosed) emit(state.copyWith(status: EstimateStatus.failed));
    }
  }

  /// Retake: the last shot and everything from it are forgotten, and the
  /// camera opens again.
  Future<void> retake() {
    emit(const FoodPhotoScannerState());
    return takePhoto();
  }

  /// Add All: [FoodPhotoScannerState.items] go on the plate at their
  /// estimates, once per shot (`onAddAllPressed`).
  void addAll() {
    if (state.addedAll || state.items.isEmpty) return;
    emit(state.copyWith(addedAll: true));
    _track('FoodPhotoScanner_AddAll', {'item_count': state.items.length});
  }

  /// A result's tap, which opens its amount sheet (`onResultTapped`).
  void resultTapped(FoodAnalysisItem item) =>
      _track('FoodPhotoScanner_AddItem', {'item_name': item.name});

  /// Open Settings, from the refused-camera message.
  Future<void> openSettings() {
    _track('FoodPhotoScanner_OpenSettings');
    return _picker.openSettings();
  }

  void _track(
    String name, [
    Map<String, Object?>? parameters,
    LogType type = LogType.analytic,
  ]) => _analytics.trackEvent(
    AnalyticsEvent(name, parameters: parameters, type: type),
  );
}

final class const FoodPhotoScannerState({
  /// The photo taken, as JPEG.
  final Uint8List? photo,

  /// Where the estimate has got to.
  final EstimateStatus status = EstimateStatus.idle,

  /// The foods found.
  final List<FoodAnalysisItem> items = const [],

  /// Whether Add All has put [items] on the plate.
  final bool addedAll = false,

  /// Whether the camera may be used.
  final CameraState camera = CameraState.ready,
}) extends Equatable {
  FoodPhotoScannerState copyWith({
    EstimateStatus? status,
    List<FoodAnalysisItem>? items,
    bool? addedAll,
    CameraState? camera,
  }) => FoodPhotoScannerState(
    photo: photo,
    status: status ?? this.status,
    items: items ?? this.items,
    addedAll: addedAll ?? this.addedAll,
    camera: camera ?? this.camera,
  );

  @override
  List<Object?> get props => [photo, status, items, addedAll, camera];
}
