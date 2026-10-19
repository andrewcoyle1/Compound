import 'dart:async';
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
/// mode): the live camera's frames are read on the device about twice a
/// second until two reads in a row show the same nutrition label, then
/// `nutritionLabelAnalyze` turns that text, once, into a food per 100 g or
/// 100 ml, which Use This Food saves to the library before it goes on to
/// the plate. A photo's text, or text typed in, is checked before it is
/// sent instead.
class LabelScannerCubit extends Cubit<LabelScannerState> {
  new({
    required this._uid,
    required this._ai,
    required this._foodRepository,
    required this._analytics,
    required this._picker,
    required this._reader,
    required this._camera,
    required this._connectivity,
    this._interval = const Duration(milliseconds: 500),
  }) : super(const LabelScannerState());

  final String _uid;
  final AiRepository _ai;
  final FoodRepository _foodRepository;
  final AnalyticsRepository _analytics;
  final PhotoPicker _picker;
  final LabelTextReader _reader;
  final LiveCamera _camera;

  /// The least time between the starts of two frame reads.
  final Duration _interval;

  /// Opening and closing the camera, one after another.
  Future<void> _cameraWork = Future.value();
  bool _cameraOpen = false;
  bool _paused = false;
  bool _closing = false;

  /// A frame is with the reader.
  bool _reading = false;

  /// Running from the start of the last frame read until the next may
  /// start.
  Timer? _throttle;

  /// The last frame's [labelKey].
  String? _lastKey;

  /// Opens the live camera to look for a label, forgetting the last result:
  /// on entering Label mode, and from Scan Again.
  Future<void> start() async {
    if (isClosed) return;
    _lastKey = null;
    emit(const LabelScannerState(status: LabelStatus.scanning));
    await _syncCamera();
  }

  /// The app has gone to the background or behind a system prompt: the
  /// camera is let go until [resume].
  Future<void> pause() {
    _paused = true;
    return _syncCamera();
  }

  /// The app is back: the camera opens again if it was looking for a
  /// label, or is tried again if it was refused (Settings may allow it).
  Future<void> resume() {
    _paused = false;
    if (state.camera == CameraState.denied) return start();
    return _syncCamera();
  }

  /// Turns the torch on or off. A camera without one loses the button.
  Future<void> toggleTorch() async {
    final on = !state.torch;
    try {
      await _camera.setTorch(on: on);
    } on Object {
      if (!isClosed && state.live) emit(state._with(hasTorch: false));
      return;
    }
    if (!isClosed && state.live) emit(state._with(torch: on));
  }

  bool get _wantsCamera =>
      !_closing &&
      !_paused &&
      state.status == LabelStatus.scanning &&
      state.camera == CameraState.ready;

  /// Opens or closes the camera to match what the state wants, after any
  /// opening or closing already under way.
  Future<void> _syncCamera() => _cameraWork = _cameraWork.then((_) async {
    if (_wantsCamera) {
      if (!_cameraOpen) {
        try {
          await _camera.open(_onFrame);
        } on PhotoAccessDeniedException {
          _track('BarcodeScanner_CameraDenied');
          if (!isClosed) {
            emit(const LabelScannerState(camera: CameraState.denied));
          }
          return;
        } on Object {
          if (!isClosed) {
            emit(const LabelScannerState(camera: CameraState.unavailable));
          }
          return;
        }
        _cameraOpen = true;
        // Wanted closed while it opened: the change queued its own sync.
        if (!_wantsCamera) return;
      }
      if (!state.live) emit(state._with(live: true, hasTorch: true));
    } else if (_cameraOpen) {
      _cameraOpen = false;
      if (!isClosed && state.live) emit(state._with(live: false));
      await _camera.close();
    }
  });

  /// About twice a second, and never while a frame is being read, a frame
  /// is read; the rest are dropped.
  void _onFrame(LabelFrame frame) {
    if (_reading || (_throttle?.isActive ?? false) || !_wantsCamera) return;
    _reading = true;
    _throttle = Timer(_interval, () {});
    unawaited(_readFrame(frame));
  }

  Future<void> _readFrame(LabelFrame frame) async {
    var text = '';
    try {
      text = await _reader.readFrame(frame);
    } on Object {
      // A frame that cannot be read is skipped.
    }
    _reading = false;
    if (isClosed || state.status != LabelStatus.scanning) return;
    final key = labelKey(text);
    if (key == null || key != _lastKey) {
      _lastKey = key;
      return;
    }
    // Locked on: the camera closes, and the text goes to the model once.
    _track('BarcodeScanner_LabelLocked');
    emit(LabelScannerState(status: LabelStatus.read, text: text));
    unawaited(_syncCamera());
    await parse(text);
  }

  /// Checked before an action that needs the server (`ensureOnline`).
  final ConnectivityRepository _connectivity;

  /// Choose from Library: the live camera closes, and the photo's text is
  /// read on the device into [LabelScannerState.text] for the label field
  /// (Swift's "Label text captured"), forgetting the last result. A cancel
  /// goes back to the live camera.
  Future<void> scan(PhotoSource source) async {
    if (isClosed) return;
    if (state.status case LabelStatus.reading || LabelStatus.parsing) return;
    final camera = state.camera;
    emit(LabelScannerState(camera: camera));
    unawaited(_syncCamera());
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
    if (isClosed) return;
    if (photo == null) {
      if (camera == CameraState.ready) await start();
      return;
    }
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
    unawaited(_syncCamera());
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

  @override
  Future<void> close() async {
    _closing = true;
    _throttle?.cancel();
    await _syncCamera();
    await super.close();
  }

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
  /// Waiting for label text, the camera closed.
  idle,

  /// The live camera is looking for a label.
  scanning,

  /// Reading a photo's text on the device.
  reading,

  /// The text of a photo, or of the label the camera locked on to, is in
  /// [LabelScannerState.text]: a photo's to check and parse, the camera's
  /// on its way to the model.
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

  /// The live camera is open, so its preview can show.
  final bool live = false,

  /// Whether to offer the torch: until it fails to light.
  final bool hasTorch = false,

  /// Whether the torch is lit.
  final bool torch = false,
}) extends Equatable {
  LabelScannerState _with({bool? live, bool? hasTorch, bool? torch}) =>
      LabelScannerState(
        status: status,
        camera: camera,
        live: live ?? this.live,
        hasTorch: (live ?? this.live) && (hasTorch ?? this.hasTorch),
        torch: (live ?? this.live) && (torch ?? this.torch),
      );

  @override
  List<Object?> get props => [
    status,
    food,
    text,
    camera,
    live,
    hasTorch,
    torch,
  ];
}

final _energy = RegExp('energ|calor|kcal', caseSensitive: false);
final _protein = RegExp('prote[ií]n', caseSensitive: false);
final _value = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(?:kcal|kj|mg|µg|mcg|ml|g|%)',
  caseSensitive: false,
);

/// What must stay the same over two reads for the live camera to lock on:
/// the label's values (each number with a unit after it), in order of
/// size, so the reader's line order does not matter. Null unless the text
/// looks like a nutrition label: energy or calories and protein, in English
/// or Spanish.
String? labelKey(String text) {
  if (!_energy.hasMatch(text) || !_protein.hasMatch(text)) return null;
  final values = [
    for (final match in _value.allMatches(text)) match[1]!.replaceAll(',', '.'),
  ]..sort();
  return values.join(' ');
}
