import 'package:compound_models/compound_models.dart';

/// Why a search or a barcode lookup failed, for the message the screen
/// shows (Swift tells "not found" apart from "couldn't reach").
enum FoodDataFailure {
  /// Open Food Facts has no product with that barcode.
  notFound,

  /// The callable refused the caller: not signed in, or App Check failed.
  unauthenticated,

  /// Too many requests: the callable's quota or Open Food Facts' HTTP 429.
  rateLimited,

  /// The network, the callable or Open Food Facts failed in any other way.
  unavailable,
}

/// A failed search or barcode lookup.
class FoodDataException implements Exception {
  /// Creates a [FoodDataException] for [failure], caused by [cause].
  const new(this.failure, [this.cause]);

  /// What went wrong.
  final FoodDataFailure failure;

  /// The underlying error, when there was one.
  final Object? cause;

  @override
  String toString() => 'FoodDataException(${failure.name}, $cause)';
}

/// Open Food Facts, as the Swift app's `OpenFoodFactsService` reaches it:
/// search through the `foodSearch` callable, barcodes from the product API.
///
/// Every food returned has no author and is not in the library; saving it
/// is the caller's choice.
abstract interface class OpenFoodFacts {
  /// Products matching [query], the user's [country] first when given (an
  /// Open Food Facts tag such as `en:ireland`) and names in [language] (a
  /// two-letter code) as well as English. A blank query finds nothing.
  ///
  /// Throws a [FoodDataException].
  Future<List<FoodModel>> searchFoods(
    String query, {
    String? country,
    String? language,
  });

  /// The product with [barcode].
  ///
  /// Throws a [FoodDataException]: [FoodDataFailure.notFound] when there is
  /// no such product.
  Future<FoodModel> lookupBarcode(String barcode);
}
