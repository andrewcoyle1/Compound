/// The signed-in user's foods and recipes from Firestore (or memory in the
/// staging flavor), Open Food Facts search and barcode lookup, and a food
/// or recipe as a meal item.
library;

export 'package:compound_models/compound_models.dart'
    show
        FoodModel,
        FoodModelKeys,
        IngredientAmountUnit,
        MealItemModel,
        MealItemSourceType,
        MealLogModel,
        MeasurementMethod,
        NutrientKey,
        NutrientMap,
        RecipeIngredientModel,
        RecipeIngredientModelKeys,
        RecipeTemplateModel,
        RecipeTemplateModelKeys,
        ServingUnit;

export 'src/barcode_lookup.dart';
export 'src/fake_open_food_facts.dart';
export 'src/firestore_food_repository.dart';
export 'src/food_meal_item.dart';
export 'src/food_repository.dart' show FoodRepository;
export 'src/in_memory_food_repository.dart';
export 'src/open_food_facts.dart';
export 'src/open_food_facts_mapping.dart'
    show openFoodFactsId, parseServingSize, productToFood, searchRowToFood;
export 'src/recipe_meal_item.dart';
export 'src/remote_open_food_facts.dart';
export 'src/sample_foods.dart';
