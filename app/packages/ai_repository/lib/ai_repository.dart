/// The AI callables (food photo, meal description, nutrition label, image
/// generation) as typed calls returning the app's models, with canned
/// answers for the staging flavor.
library;

export 'package:compound_models/compound_models.dart'
    show FoodModel, MealItemModel, NutrientKey, NutrientMap;

export 'src/ai_repository.dart';
export 'src/food_analysis_item.dart';
export 'src/staging_ai_call.dart';
