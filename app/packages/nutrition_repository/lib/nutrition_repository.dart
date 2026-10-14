/// Reads the signed-in user's meal logs, diet plan and food log settings
/// from Firestore, or from memory in the staging flavor, and saves meals and
/// the diet plan.
library;

export 'package:compound_models/compound_models.dart'
    show
        DailyMacroTarget,
        DietPlan,
        FoodLogSettings,
        MealItemModel,
        MealItemSourceType,
        MealLogModel,
        NutrientKey,
        NutrientMap,
        TimestampSide;

export 'src/firestore_nutrition_repository.dart';
export 'src/in_memory_nutrition_repository.dart';
export 'src/meal_days.dart';
export 'src/nutrition_repository.dart';
export 'src/sample_nutrition.dart';
