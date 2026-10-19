import 'dart:typed_data';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/nutrition/foods/logic/create_food.dart';
import 'package:compound/nutrition/logic/meal_logging.dart' show EnergyUnit;
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';
import 'package:image_repository/image_repository.dart';

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

  /// The food's picture, picked on the name step and uploaded by Create.
  final Uint8List? photo,

  /// Whether Create & Add was the button pressed.
  final bool addToPlate = false,
}) extends Equatable {
  /// The name step's Next (`CreateFoodPresenter.canSave`).
  bool get canContinue => name.trim().isNotEmpty;

  /// Anything typed that closing would throw away
  /// (`CreateFoodPresenter.hasUnsavedChanges`).
  bool get hasUnsavedChanges =>
      name.trim().isNotEmpty ||
      (brandName ?? '').isNotEmpty ||
      barcode != null ||
      photo != null;

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
    Uint8List? photo,
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
    photo: photo ?? this.photo,
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
    photo,
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
    required this._images,
    required this._picker,
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : super(const CreateFoodState());

  final String? _uid;
  final FoodRepository _foods;
  final AnalyticsRepository _analytics;
  final ImageRepository _images;
  final PhotoPicker _picker;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Records one of the flow's screens appearing: `CreateFoodView`,
  /// `PortionDefinitionView` or `FoodDefinitionView`.
  void appeared(String screen) => _analytics.appear(screen);

  /// Records one of the flow's screens going.
  void disappeared(String screen) => _analytics.disappear(screen);

  /// Where a food's picture is stored (`FoodManager.saveFood`).
  static String photoPath(String foodId) => 'ingredient_templates/$foodId';

  /// The image button (`CreateFoodPresenter.onImageSelectorPressed` and
  /// `onImageSelectorChanged`): a photo from the library, shown at once and
  /// uploaded by Create.
  Future<void> photoPressed() async {
    _analytics.analytic('IngredientImageSelector_Start');
    final Uint8List? photo;
    try {
      photo = await _picker.pick(PhotoSource.library, PhotoSize.standard);
    } on Object catch (error) {
      _analytics.severe('IngredientImageSelector_Fail', error);
      return;
    }
    if (photo == null) {
      _analytics.analytic('IngredientImageSelector_Cancel');
      return;
    }
    _analytics.analytic('IngredientImageSelector_Success');
    if (!isClosed) emit(state.copyWith(photo: photo));
  }

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
    final id = _newId();
    final photo = state.photo;
    FoodModel food(String? imageUrl) => createdFood(
      id: id,
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
      imageUrl: imageUrl,
    );
    try {
      // The picture first, as Swift uploads it before saving: an upload
      // needs the server, so offline the food is not created.
      final created = food(
        photo == null ? null : await _images.upload(photo, photoPath(id)),
      );
      await _foods.saveFood(created);
      _analytics.analytic('FoodDefinitionView_CreateFood_Success');
      emit(state.copyWith(status: CreateFoodStatus.created, created: created));
    } on Object catch (error) {
      _analytics.severe('FoodDefinitionView_CreateFood_Fail', error);
      emit(state.copyWith(status: CreateFoodStatus.failed));
    }
  }
}
