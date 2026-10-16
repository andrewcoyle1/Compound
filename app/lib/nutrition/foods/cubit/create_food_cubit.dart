import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/app/document_id.dart';
import 'package:compound/nutrition/foods/logic/create_food.dart';
import 'package:compound/nutrition/logic/meal_logging.dart' show EnergyUnit;
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';

/// Where the create flow's save is.
enum CreateFoodStatus {
  /// Being filled in.
  editing,

  /// Saving.
  saving,

  /// Saved; the flow closes with [CreateFoodState.created].
  created,

  /// The save failed; the form stays open.
  failed,
}

/// The food being created, across its three steps.
final class const CreateFoodState({
  final String name = '',
  final String? brandName,
  final String? barcode,
  final NutritionDefinitionOption option = NutritionDefinitionOption.serving,
  final double? servingWeight,
  final double? portionSize = 1,
  final String portionName = 'portion',
  final double? energy,
  final EnergyUnit energyUnit = EnergyUnit.kcal,
  final Map<NutrientKey, double> nutrients = const {},
  final CreateFoodStatus status = CreateFoodStatus.editing,
  final FoodModel? created,

  /// Whether Create & Add was the button pressed.
  final bool addToPlate = false,
}) extends Equatable {
  /// The name step's Next (`CreateFoodPresenter.canSave`).
  bool get canContinue => name.trim().isNotEmpty;

  /// Anything typed that closing would throw away
  /// (`CreateFoodPresenter.hasUnsavedChanges`).
  bool get hasUnsavedChanges =>
      name.trim().isNotEmpty || (brandName ?? '').isNotEmpty || barcode != null;

  /// The portion this food is defined by.
  PortionInput get portion => (
    option: option,
    servingWeight: servingWeight,
    portionSize: portionSize,
    portionName: portionName,
  );

  /// The portion step's Next.
  bool get canContinuePortionStep => canContinuePortion(portion);

  /// Energy is the one figure every food has; without it the food would
  /// count for nothing (`FoodDefinitionPresenter.canCreate`).
  bool get canCreate => (energy ?? 0) > 0;

  /// Whether a save is under way, so a second tap cannot save twice.
  bool get isSaving => status == CreateFoodStatus.saving;

  CreateFoodState copyWith({
    String? name,
    String? Function()? brandName,
    String? Function()? barcode,
    double? Function()? servingWeight,
    double? Function()? portionSize,
    String? portionName,
    double? Function()? energy,
    EnergyUnit? energyUnit,
    Map<NutrientKey, double>? nutrients,
    CreateFoodStatus? status,
    FoodModel? created,
    bool? addToPlate,
  }) => CreateFoodState(
    name: name ?? this.name,
    brandName: brandName == null ? this.brandName : brandName(),
    barcode: barcode == null ? this.barcode : barcode(),
    option: option,
    servingWeight: servingWeight == null ? this.servingWeight : servingWeight(),
    portionSize: portionSize == null ? this.portionSize : portionSize(),
    portionName: portionName ?? this.portionName,
    energy: energy == null ? this.energy : energy(),
    energyUnit: energyUnit ?? this.energyUnit,
    nutrients: nutrients ?? this.nutrients,
    status: status ?? this.status,
    created: created ?? this.created,
    addToPlate: addToPlate ?? this.addToPlate,
  );

  @override
  List<Object?> get props => [
    name,
    brandName,
    barcode,
    option,
    servingWeight,
    portionSize,
    portionName,
    energy,
    energyUnit,
    nutrients,
    status,
    created?.ingredientId,
    addToPlate,
  ];
}

/// Creating a food (Swift `CreateFoodPresenter`, `PortionDefinitionPresenter`
/// and `FoodDefinitionPresenter`): its name, brand and barcode; the serving
/// its figures describe; then the figures, saved to the user's library.
class CreateFoodCubit extends Cubit<CreateFoodState> {
  /// `uid` is the signed-in user, who authors the food; without one nothing
  /// is saved.
  new({
    required this._uid,
    required this._foods,
    required this._analytics,
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : super(const CreateFoodState());

  final String? _uid;
  final FoodRepository _foods;
  final AnalyticsRepository _analytics;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Records one of the flow's screens appearing: `CreateFoodView`,
  /// `PortionDefinitionView` or `FoodDefinitionView`.
  void appeared(String screen) => _analytics.appear(screen);

  /// Records one of the flow's screens going.
  void disappeared(String screen) => _analytics.disappear(screen);

  /// The name as typed.
  void nameChanged(String name) => emit(state.copyWith(name: name));

  /// The brand as typed; empty is none.
  void brandChanged(String brand) =>
      emit(state.copyWith(brandName: () => brand.isEmpty ? null : brand));

  /// The barcode scanned or typed (`CreateFoodPresenter
  /// .onBarcodeScannerPressed`'s callback).
  void barcodeScanned(String barcode) =>
      emit(state.copyWith(barcode: () => barcode));

  /// The serving's weight in grams.
  void servingWeightChanged(double? weight) =>
      emit(state.copyWith(servingWeight: () => weight));

  /// How many of the portion name a serving is.
  void portionSizeChanged(double? size) =>
      emit(state.copyWith(portionSize: () => size));

  /// The portion's name, such as `slice`.
  void portionNameChanged(String name) =>
      emit(state.copyWith(portionName: name));

  /// The energy as typed, in [CreateFoodState.energyUnit].
  void energyChanged(double? energy) =>
      emit(state.copyWith(energy: () => energy));

  /// The unit energy is typed in.
  void energyUnitChanged(EnergyUnit unit) =>
      emit(state.copyWith(energyUnit: unit));

  /// [key] as typed; null clears it.
  void nutrientChanged(NutrientKey key, double? value) => emit(
    state.copyWith(
      nutrients: {
        for (final entry in state.nutrients.entries)
          if (entry.key != key) entry.key: entry.value,
        key: ?value,
      },
    ),
  );

  /// Create, or Create & Add when [addToPlate]: saves the food between
  /// `FoodDefinitionView_CreateFood_Start` and `_Success` or a severe
  /// `_Fail`. Does nothing without energy, while saving, or signed out.
  Future<void> create({bool addToPlate = false}) async {
    final uid = _uid;
    final energy = state.energy;
    if (!state.canCreate || state.isSaving || uid == null || energy == null) {
      return;
    }
    emit(
      state.copyWith(status: CreateFoodStatus.saving, addToPlate: addToPlate),
    );
    _analytics.analytic('FoodDefinitionView_CreateFood_Start');
    final food = createdFood(
      id: _newId(),
      authorId: uid,
      name: state.name,
      brandName: state.brandName,
      barcode: state.barcode,
      portion: state.portion,
      nutrients: {
        NutrientKey.calories: energyInKilocalories(energy, state.energyUnit),
        ...state.nutrients,
      },
      now: _now(),
    );
    try {
      await _foods.saveFood(food);
      _analytics.analytic('FoodDefinitionView_CreateFood_Success');
      emit(state.copyWith(status: CreateFoodStatus.created, created: food));
    } on Object catch (error) {
      _analytics.severe('FoodDefinitionView_CreateFood_Fail', error);
      emit(state.copyWith(status: CreateFoodStatus.failed));
    }
  }
}
