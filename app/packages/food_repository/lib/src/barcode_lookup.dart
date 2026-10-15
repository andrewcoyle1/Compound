import 'package:compound_models/compound_models.dart';
import 'package:food_repository/src/food_repository.dart';
import 'package:food_repository/src/open_food_facts.dart';

/// Where [lookUpBarcode] found a food.
enum BarcodeSource {
  /// The user's own library.
  library,

  /// Open Food Facts; the food has just been saved to the library.
  openFoodFacts,
}

/// The food with [barcode], as the Swift scanner finds it
/// (`BarcodeScannerPresenter.onBarcodeDetected`):
///
/// 1. the first food in [library] with that barcode;
/// 2. otherwise Open Food Facts' product, saved to [uid]'s library through
///    [foods] so the next scan finds it there. The save is a side effect:
///    if it fails the error goes to [onSaveError] and the scan still
///    succeeds, with the food as it would have been saved.
///
/// Throws Open Food Facts' [FoodDataException]. The caller checks the
/// connection first, as Swift's `ensureOnline` does.
Future<(FoodModel, BarcodeSource)> lookUpBarcode(
  String barcode, {
  required String uid,
  required List<FoodModel> library,
  required OpenFoodFacts openFoodFacts,
  required FoodRepository foods,
  required void Function(Object error, StackTrace stackTrace) onSaveError,
}) async {
  for (final food in library) {
    if (food.barcode == barcode) return (food, BarcodeSource.library);
  }
  final food = withAuthor(await openFoodFacts.lookupBarcode(barcode), uid);
  try {
    await foods.saveFood(food);
  } on Object catch (error, stackTrace) {
    onSaveError(error, stackTrace);
  }
  return (food, BarcodeSource.openFoodFacts);
}
