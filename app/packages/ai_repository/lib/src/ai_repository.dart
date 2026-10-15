import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_repository/src/food_analysis_item.dart';
import 'package:ai_repository/src/random_id.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:compound_models/compound_models.dart';

/// The region of the AI callables. The app passes
/// `FirebaseFunctions.instanceFor(region: aiFunctionsRegion)` to
/// [callAiFunction], on an app with App Check activated: every callable
/// enforces it.
const aiFunctionsRegion = 'us-central1';

/// Calls the Cloud Function [name] with [data] and returns what it answers,
/// throwing a [FirebaseFunctionsException] when it refuses.
typedef CallFunction = Future<Object?> Function(
  String name,
  Map<String, Object?> data,
);

/// [CallFunction] on Cloud Functions (Swift `GoogleAIService`). [functions]
/// must be in [aiFunctionsRegion].
CallFunction callAiFunction(FirebaseFunctions functions) =>
    (name, data) async =>
        (await functions.httpsCallable(name).call<Object?>(data)).data;

/// Why an AI call failed, for the message the screen shows.
enum AiFailure {
  /// Not signed in, or App Check refused the app (`unauthenticated`).
  unauthenticated,

  /// The function refused the caller (`permission-denied`).
  permissionDenied,

  /// Too many requests: Vertex AI's quota (`resource-exhausted`).
  rateLimited,

  /// The network or the function failed in any other way.
  unavailable,

  /// The function answered something that is not what was asked for: the
  /// model's JSON did not match the schema (Swift's decode failure).
  invalidResponse,
}

/// A failed AI call.
class const AiException(
  /// What went wrong.
  final AiFailure failure, [

  /// The underlying error, when there was one.
  final Object? cause,
]) implements Exception {
  /// Creates an [AiException].
  this;

  @override
  String toString() => 'AiException(${failure.name}, $cause)';
}

/// The AI callables as typed calls (Swift `AIManager` and `GoogleAIService`,
/// with the decoding its presenters do): `foodAnalyze`, `mealDescribe`,
/// `nutritionLabelAnalyze` and `imageGenerate`.
///
/// Every method throws an [AiException]. The staging flavor passes
/// `stagingAiCall`, which answers as Swift's `MockAIService` does.
class AiRepository {
  /// Creates an [AiRepository]. [now] stamps the food a label becomes, and
  /// [newId] names it.
  new({
    required this._callFunction,
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? (() => DateTime.now().toUtc()),
       _newId = newId ?? randomUuid;

  final CallFunction _callFunction;
  final DateTime Function() _now;
  final String Function() _newId;

  /// The foods in a photo, sent as [jpeg] (Swift sends JPEG at 0.8
  /// quality). Each item carries the `ingredientId` the function filed it
  /// under.
  Future<List<FoodAnalysisItem>> analyzeFood(Uint8List jpeg) async =>
      _items(await _result('foodAnalyze', {'imageBase64': base64Encode(jpeg)}));

  /// The foods in a meal described in words.
  Future<List<FoodAnalysisItem>> describeMeal(String description) async =>
      _items(await _result('mealDescribe', {'description': description}));

  /// The food on a nutrition label, from the label's recognized text, as a
  /// new food owned by [authorId] with its nutrients per 100 g or 100 ml
  /// (`NutritionLabelResponse.toFood`). It is not saved.
  Future<FoodModel> analyzeNutritionLabel(
    String labelText, {
    String? authorId,
  }) async {
    final json = await _result('nutritionLabelAnalyze', {
      'labelText': labelText,
    });
    return _decode<FoodModel>(() {
      final label = json! as Map<String, Object?>;
      final nutrients = <NutrientKey, double>{};
      for (final (field, key) in _labelNutrients) {
        if ((label[field] as num?)?.toDouble() case final value?) {
          nutrients[key] = value;
        }
      }
      final now = _now();
      return FoodModel(
        ingredientId: _newId(),
        authorId: authorId,
        name: label['name']! as String,
        measurementMethod: (label['measurementMethod'] as String?) == 'volume'
            ? MeasurementMethod.volume
            : MeasurementMethod.weight,
        nutrients: NutrientMap(nutrients),
        dateCreated: now,
        dateModified: now,
      );
    });
  }

  /// An image for [prompt], as the encoded bytes Imagen returned (PNG).
  Future<Uint8List> generateImage(String prompt) async {
    final data = await _call('imageGenerate', {'prompt': prompt});
    return _decode<Uint8List>(
      () => base64Decode((data! as Map<Object?, Object?>)['base64']! as String),
    );
  }

  /// The label fields and the nutrient each fills.
  static const List<(String, NutrientKey)> _labelNutrients = [
    ('calories', NutrientKey.calories),
    ('protein', NutrientKey.protein),
    ('carbs', NutrientKey.carbs),
    ('fatTotal', NutrientKey.fatTotal),
    ('fatSaturated', NutrientKey.fatSaturated),
    ('fiber', NutrientKey.fiber),
    ('sugar', NutrientKey.sugar),
    ('sodiumMg', NutrientKey.sodiumMg),
    ('potassiumMg', NutrientKey.potassiumMg),
    ('calciumMg', NutrientKey.calciumMg),
    ('ironMg', NutrientKey.ironMg),
  ];

  /// The `{items: [...]}` the food callables answer.
  List<FoodAnalysisItem> _items(Object? json) => _decode(
    () => [
      for (final item
          in (json! as Map<String, Object?>)['items']! as List<Object?>)
        FoodAnalysisItem.fromJson(item! as Map<String, Object?>),
    ],
  );

  /// The model's JSON, which the food and label callables return as the
  /// string `result`.
  Future<Object?> _result(String name, Map<String, Object?> data) async {
    final answer = await _call(name, data);
    return _decode<Object?>(
      () => jsonDecode((answer! as Map<Object?, Object?>)['result']! as String),
    );
  }

  Future<Object?> _call(String name, Map<String, Object?> data) async {
    try {
      return await _callFunction(name, data);
    } on FirebaseFunctionsException catch (error) {
      throw AiException(switch (error.code) {
        'unauthenticated' => AiFailure.unauthenticated,
        'permission-denied' => AiFailure.permissionDenied,
        'resource-exhausted' => AiFailure.rateLimited,
        _ => AiFailure.unavailable,
      }, error);
    }
  }

  /// [decode], with anything it throws (a missing field, a wrong type,
  /// malformed JSON or base64) as [AiFailure.invalidResponse].
  static T _decode<T>(T Function() decode) {
    try {
      return decode();
    } on Object catch (error) {
      throw AiException(AiFailure.invalidResponse, error);
    }
  }
}
