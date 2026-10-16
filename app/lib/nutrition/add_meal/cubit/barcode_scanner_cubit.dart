import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';

/// The picker's barcode tab (Swift `BarcodeScannerPresenter`, barcode mode):
/// a code from the camera or typed in is looked up in the user's library,
/// then on Open Food Facts, whose product is saved to the library.
class BarcodeScannerCubit extends Cubit<BarcodeScannerState> {
  new({
    required this._uid,
    required this._openFoodFacts,
    required this._foodRepository,
    required this._analyticsRepository,
  }) : super(const BarcodeScannerState());

  final String _uid;
  final OpenFoodFacts _openFoodFacts;
  final FoodRepository _foodRepository;
  final AnalyticsRepository _analyticsRepository;

  /// [code] was read by the camera or typed. The same code again does
  /// nothing until [rescan], since the camera reports a code it can see
  /// many times a second.
  Future<void> detected(String code, {required List<FoodModel> library}) async {
    final barcode = code.trim();
    if (barcode.isEmpty || barcode == state.code) return;
    emit(BarcodeScannerState(code: barcode, status: BarcodeStatus.lookingUp));
    _analyticsRepository.trackEvent(
      AnalyticsEvent(
        'BarcodeScanner_BarcodeDetected',
        parameters: {'code': barcode},
      ),
    );
    try {
      final (food, source) = await lookUpBarcode(
        barcode,
        uid: _uid,
        library: library,
        openFoodFacts: _openFoodFacts,
        foods: _foodRepository,
        onSaveError: (error, _) => _analyticsRepository.trackEvent(
          AnalyticsEvent(
            'BarcodeScannerView_CacheFood_Fail',
            parameters: {'error_description': '$error'},
            type: LogType.warning,
          ),
        ),
      );
      _analyticsRepository.trackEvent(
        AnalyticsEvent(
          'BarcodeScannerView_LookupBarcode_Success',
          parameters: {
            'source': switch (source) {
              BarcodeSource.library => 'library',
              BarcodeSource.openFoodFacts => 'open_food_facts',
            },
          },
        ),
      );
      emit(state.copyWith(status: BarcodeStatus.found, food: food));
    } on Object catch (error) {
      _analyticsRepository.trackEvent(
        AnalyticsEvent(
          'BarcodeScanner_BarcodeError',
          parameters: {'error': '$error'},
          type: LogType.severe,
        ),
      );
      final notFound =
          error is FoodDataException &&
          error.failure == FoodDataFailure.notFound;
      emit(
        state.copyWith(
          status: notFound ? BarcodeStatus.notFound : BarcodeStatus.unavailable,
        ),
      );
    }
  }

  /// Scan again: the last code and its result are forgotten.
  void rescan() => emit(const BarcodeScannerState());
}

/// Where a scan has got to.
enum BarcodeStatus {
  /// Waiting for a code.
  scanning,

  /// Looking the code up.
  lookingUp,

  /// Found [BarcodeScannerState.food].
  found,

  /// Open Food Facts has no such product.
  notFound,

  /// Open Food Facts couldn't be reached or refused.
  unavailable,
}

final class const BarcodeScannerState({
  /// The code being looked up or last looked up.
  final String? code,

  /// Where the scan has got to.
  final BarcodeStatus status = BarcodeStatus.scanning,

  /// The food found.
  final FoodModel? food,
}) extends Equatable {
  BarcodeScannerState copyWith({BarcodeStatus? status, FoodModel? food}) =>
      BarcodeScannerState(
        code: code,
        status: status ?? this.status,
        food: food ?? this.food,
      );

  @override
  List<Object?> get props => [code, status, food];
}
