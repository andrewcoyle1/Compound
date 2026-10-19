import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:compound_models/compound_models.dart';
import 'package:food_repository/src/open_food_facts.dart';
import 'package:food_repository/src/open_food_facts_mapping.dart';
import 'package:http/http.dart' as http;
import 'package:openfoodfacts/openfoodfacts.dart' as off;

/// [OpenFoodFacts] over the network (Swift
/// `ProductionOpenFoodFactsService`).
///
/// Search calls the `foodSearch` callable, which enforces App Check and
/// sign-in, so `functions` must be `FirebaseFunctions.instanceFor(region:
/// 'us-central1')` on an app with App Check activated. Barcodes are read
/// straight from Open Food Facts' product API through the `openfoodfacts`
/// package, which opens its own `http.Client` per request (so tests swap it
/// with `http.runWithClient`).
class RemoteOpenFoodFacts implements OpenFoodFacts {
  /// Creates a [RemoteOpenFoodFacts]. `now` stamps the foods it makes, and
  /// `newId` names a search result that has no barcode.
  new({
    required this._functions,
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? (() => DateTime.now().toUtc()),
       _newId = newId ?? newDocumentId;

  final FirebaseFunctions _functions;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Open Food Facts asks every app to name itself; anonymous traffic is
  /// the first to be rate-limited.
  static const userAgent = 'Compound/1.0 (Flutter; contact@dialedinapp.com)';

  @override
  Future<List<FoodModel>> searchFoods(
    String query, {
    String? country,
    String? language,
  }) async {
    if (query.trim().isEmpty) return const [];
    final Object? data;
    try {
      data = (await _functions.httpsCallable('foodSearch').call<Object?>({
        'query': query,
        'country': ?country,
        'lang': ?language,
      })).data;
    } on FirebaseFunctionsException catch (error) {
      throw FoodDataException(switch (error.code) {
        'unauthenticated' ||
        'permission-denied' => FoodDataFailure.unauthenticated,
        'resource-exhausted' => FoodDataFailure.rateLimited,
        _ => FoodDataFailure.unavailable,
      }, error);
    }
    final products = data is Map ? data['products'] : null;
    if (products is! List) return const [];
    final now = _now();
    return [
      for (final row in products)
        if (row is Map) ?searchRowToFood(row, now: now, newId: _newId),
    ];
  }

  @override
  Future<FoodModel> lookupBarcode(String barcode) async {
    if (barcode.isEmpty) {
      throw const FoodDataException(FoodDataFailure.notFound);
    }
    off.OpenFoodAPIConfiguration.userAgent = _userAgent;
    final http.Response response;
    try {
      // The v3 product API: its `product` is the same raw object as v2's,
      // so productToFood reads it unchanged. The package percent-encodes
      // the code, so a typed code cannot reach another endpoint.
      response = await off.ProductQueryConfiguration(
        barcode,
        version: off.ProductQueryVersion.v3,
      ).getResponse(null, off.uriHelperFoodProd);
    } on http.ClientException catch (error) {
      throw FoodDataException(FoodDataFailure.unavailable, error);
    }
    // A burst of lookups gets a 429 page, which Swift used to read as "not
    // found", sending people off to re-enter a barcode that was fine.
    if (response.statusCode == 429) {
      throw const FoodDataException(FoodDataFailure.rateLimited);
    }
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw FoodDataException(FoodDataFailure.unavailable, error);
    }
    if (body is! Map<String, Object?>) {
      throw const FoodDataException(FoodDataFailure.unavailable);
    }
    // v3 answers an unknown code with a 404 whose body has no product.
    final product = body['product'];
    final food = product is Map<String, Object?>
        ? productToFood(product, barcode: barcode, now: _now())
        : null;
    if (food == null) throw const FoodDataException(FoodDataFailure.notFound);
    return food;
  }
}

final _userAgent = _ExactUserAgent();

/// The package writes a user agent as " - name - version - …"; this keeps
/// the header exactly [RemoteOpenFoodFacts.userAgent].
class _ExactUserAgent extends off.UserAgent {
  new() : super(name: RemoteOpenFoodFacts.userAgent);

  @override
  String toValueString() => name;
}
