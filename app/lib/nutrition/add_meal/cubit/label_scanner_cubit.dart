import 'dart:typed_data';

import 'package:ai_repository/ai_repository.dart';
import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/nutrition/add_meal/cubit/food_photo_scanner_cubit.dart'
    show CameraState;
import 'package:connectivity_repository/connectivity_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';
import 'package:image_repository/image_repository.dart';

/// The Barcode tab's Label mode (Swift `BarcodeScannerPresenter`, label
/// mode): a photo of a nutrition label is read on the device into text,
/// which can be checked or typed instead, then `nutritionLabelAnalyze`
/// turns the text into a food per 100 g or 100 ml, which Use This Food
/// saves to the library before it goes on to the plate.
class LabelScannerCubit extends Cubit<LabelScannerState> {
  new({
    required this._uid,
    required this._ai,
    required this._foodRepository,
    required this._analytics,
    required this._picker,
    required this._reader,
    required this._connectivity,
  }) : super(const LabelScannerState());

  final String _uid;
  final AiRepository _ai;
  final FoodRepository _foodRepository;
  final AnalyticsRepository _analytics;
  final PhotoPicker _picker;
  final LabelTextReader _reader;

  /// Checked before an action that needs the server (`ensureOnline`).
  final ConnectivityRepository _connectivity;

  /// Scan Label or Choose from Library: the photo's text is read on the
  /// device into [LabelScannerState.text] for the label field (Swift's
  /// "Label text captured"), forgetting the last result. A cancel leaves
  /// the mode as it was.
  Future<void> scan(PhotoSource source) async {
    if (state.status case LabelStatus.reading || LabelStatus.parsing) return;
    final Uint8List? photo;
    try {
      photo = await _picker.pick(source, PhotoSize.labelPhoto);
    } on PhotoAccessDeniedException {
      _track('BarcodeScanner_CameraDenied');
      if (!isClosed) emit(const LabelScannerState(camera: CameraState.denied));
      return;
    } on Object {
      if (!isClosed) {
        emit(const LabelScannerState(camera: CameraState.unavailable));
      }
      return;
    }
    if (photo == null || isClosed) return;
    emit(const LabelScannerState(status: LabelStatus.reading));
    try {
      final text = await _reader.read(photo);
      if (isClosed) return;
      emit(
        text.isEmpty
            ? const LabelScannerState(status: LabelStatus.unreadable)
            : LabelScannerState(status: LabelStatus.read, text: text),
      );
    } on Object catch (error) {
      _labelError(error);
      if (!isClosed) {
        emit(const LabelScannerState(status: LabelStatus.unreadable));
      }
    }
  }

  /// Open Settings, from the refused-camera message.
  Future<void> openSettings() {
    _track('BarcodeScanner_OpenSettings');
    return _picker.openSettings();
  }

  /// Parse Label: [text] goes to the model, forgetting the last result.
  /// Nothing is sent without text, or while a parse is out.
  Future<void> parse(String text) async {
    final label = text.trim();
    if (label.isEmpty) return;
    if (state.status case LabelStatus.parsing || LabelStatus.reading) return;
    if (!_connectivity.ensureOnline()) return;
    emit(const LabelScannerState(status: LabelStatus.parsing));
    _track('BarcodeScanner_ParseLabel');
    try {
      final food = await _ai.analyzeNutritionLabel(label, authorId: _uid);
      _track('BarcodeScannerView_ParseLabel_Success');
      if (!isClosed) {
        emit(LabelScannerState(status: LabelStatus.parsed, food: food));
      }
    } on Object catch (error) {
      _labelError(error);
      if (!isClosed) emit(const LabelScannerState(status: LabelStatus.failed));
    }
  }

  /// Use This Food: the food is saved to the library, then is
  /// [LabelStatus.saved] for the plate (`onUseLabelFoodPressed`). A save
  /// that could not start keeps the result to try again.
  Future<void> use() async {
    final food = state.food;
    if (food == null || state.status == LabelStatus.saving) return;
    emit(LabelScannerState(status: LabelStatus.saving, food: food));
    _track('BarcodeScanner_SaveIngredient', {'ingredient_name': food.name});
    try {
      await _foodRepository.saveFood(food);
    } on Object catch (error) {
      _labelError(error);
      if (!isClosed) {
        emit(LabelScannerState(status: LabelStatus.saveFailed, food: food));
      }
      return;
    }
    _track('BarcodeScannerView_SaveIngredient_Success');
    if (!isClosed) {
      emit(LabelScannerState(status: LabelStatus.saved, food: food));
    }
  }

  /// Dismiss, Re-scan or a change of mode: the result is forgotten.
  void dismiss() => emit(const LabelScannerState());

  void _labelError(Object error) => _analytics.trackEvent(
    AnalyticsEvent(
      'BarcodeScanner_LabelError',
      parameters: {'error': '$error'},
      type: LogType.severe,
    ),
  );

  void _track(String name, [Map<String, Object?>? parameters]) =>
      _analytics.trackEvent(AnalyticsEvent(name, parameters: parameters));
}

/// Where reading a label has got to.
enum LabelStatus {
  /// Waiting for label text.
  idle,

  /// Reading a photo's text on the device.
  reading,

  /// The photo's text is in [LabelScannerState.text], to check and parse.
  read,

  /// No text could be read from the photo.
  unreadable,

  /// The model is reading it.
  parsing,

  /// Read into [LabelScannerState.food].
  parsed,

  /// The label could not be read.
  failed,

  /// Saving [LabelScannerState.food] to the library.
  saving,

  /// The save could not start; [LabelScannerState.food] is kept.
  saveFailed,

  /// [LabelScannerState.food] is in the library, to go on the plate.
  saved,
}

final class const LabelScannerState({
  /// Where reading the label has got to.
  final LabelStatus status = LabelStatus.idle,

  /// The food the label became.
  final FoodModel? food,

  /// The text read from the label's photo.
  final String? text,

  /// Whether the camera may be used.
  final CameraState camera = CameraState.ready,
}) extends Equatable {
  @override
  List<Object?> get props => [status, food, text, camera];
}
