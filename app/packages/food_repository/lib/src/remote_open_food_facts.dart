import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:compound_models/compound_models.dart';
import 'package:food_repository/src/open_food_facts.dart';
import 'package:food_repository/src/open_food_facts_mapping.dart';
import 'package:http/http.dart' as http;

/// [OpenFoodFacts] over the network (Swift
/// `ProductionOpenFoodFactsService`).
///
/// Search calls the `foodSearch` callable, which enforces App Check and
/// sign-in, so `functions` must be `FirebaseFunctions.instanceFor(region:
/// 'us-central1')` on an app with App Check activated. Barcodes are read
/// straight from Open Food Facts' product API with `client`.
class RemoteOpenFoodFacts implements OpenFoodFacts {
  /// Creates a [RemoteOpenFoodFacts]. `now` stamps the foods it makes, and
  /// `newId` names a search result that has no barcode.
  new({
    required this._functions,
    required this._client,
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? (() => DateTime.now().toUtc()),
       _newId = newId ?? newDocumentId;

  final FirebaseFunctions _functions;
  final http.Client _client;
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
    final http.Response response;
    try {
      response = await _client.get(
        Uri(
          scheme: 'https',
          host: 'world.openfoodfacts.org',
          // Path segments, so a typed code cannot reach another endpoint.
          pathSegments: ['api', 'v2', 'product', '$barcode.json'],
        ),
        headers: {'User-Agent': userAgent},
      );
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
    final product = body['product'];
    final food = body['status'] == 1 && product is Map<String, Object?>
        ? productToFood(product, barcode: barcode, now: _now())
        : null;
    if (food == null) throw const FoodDataException(FoodDataFailure.notFound);
    return food;
  }
}
