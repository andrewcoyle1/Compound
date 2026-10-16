import 'package:cloud_functions/cloud_functions.dart';

/// The AI callables (a `CallFunction`) for the staging flavor and tests,
/// answering as Swift's `MockAIService` does: the same three foods for a
/// photo or a description, a protein shake mix for a label, and a one-pixel
/// PNG for an image. Nothing leaves the device. Any other name is refused
/// as `not-found`.
Future<Object?> stagingAiCall(String name, Map<String, Object?> data) async =>
    switch (name) {
      'foodAnalyze' || 'mealDescribe' => {'result': _items},
      'nutritionLabelAnalyze' => {'result': _label},
      'imageGenerate' => {'base64': _pixel},
      _ => throw FirebaseFunctionsException(
        message: 'No such function: $name',
        code: 'not-found',
      ),
    };

const _items = '''
{"items":[
  {"id":"1","name":"Grilled Chicken Breast","amountGrams":150,"calories":248,"proteinGrams":46.5,"carbGrams":0,"fatGrams":5.4},
  {"id":"2","name":"Brown Rice","amountGrams":100,"calories":111,"proteinGrams":2.6,"carbGrams":23,"fatGrams":0.9},
  {"id":"3","name":"Steamed Broccoli","amountGrams":80,"calories":27,"proteinGrams":2.4,"carbGrams":5,"fatGrams":0.3}
]}''';

const _label = '''
{
  "name": "Protein Shake Mix",
  "measurementMethod": "weight",
  "calories": 380,
  "protein": 30.0,
  "carbs": 45.0,
  "fatTotal": 5.0,
  "fatSaturated": 1.5,
  "fiber": 3.0,
  "sugar": 8.0,
  "sodiumMg": 250,
  "potassiumMg": 420,
  "calciumMg": 200,
  "ironMg": 2.5
}''';

/// A 1×1 transparent PNG.
const _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
