import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/progress/logic/body_metrics.dart';
import 'package:compound/progress/logic/nutrition_analytics.dart';
import 'package:compound_maths/compound_maths.dart' show BodyRatioKind;
import 'package:intl/intl.dart' show NumberFormat;

/// A circumference's name, such as "Left Bicep".
String bodyMeasurementName(AppLocalizations l10n, BodyMeasurementKind kind) =>
    switch (kind) {
      BodyMeasurementKind.neck => l10n.measurementNeck,
      BodyMeasurementKind.shoulders => l10n.measurementShoulders,
      BodyMeasurementKind.bust => l10n.measurementBust,
      BodyMeasurementKind.chest => l10n.measurementChest,
      BodyMeasurementKind.waist => l10n.measurementWaist,
      BodyMeasurementKind.hips => l10n.measurementHips,
      BodyMeasurementKind.leftBicep => l10n.measurementLeftBicep,
      BodyMeasurementKind.rightBicep => l10n.measurementRightBicep,
      BodyMeasurementKind.leftForearm => l10n.measurementLeftForearm,
      BodyMeasurementKind.rightForearm => l10n.measurementRightForearm,
      BodyMeasurementKind.leftWrist => l10n.measurementLeftWrist,
      BodyMeasurementKind.rightWrist => l10n.measurementRightWrist,
      BodyMeasurementKind.leftThigh => l10n.measurementLeftThigh,
      BodyMeasurementKind.rightThigh => l10n.measurementRightThigh,
      BodyMeasurementKind.leftCalf => l10n.measurementLeftCalf,
      BodyMeasurementKind.rightCalf => l10n.measurementRightCalf,
      BodyMeasurementKind.leftAnkle => l10n.measurementLeftAnkle,
      BodyMeasurementKind.rightAnkle => l10n.measurementRightAnkle,
    };

/// A Body Metrics group's heading.
String bodyMetricsGroupName(AppLocalizations l10n, BodyMetricsGroup group) =>
    switch (group) {
      BodyMetricsGroup.weightAndBodyFat => l10n.bodyMetricsWeightAndBodyFat,
      BodyMetricsGroup.upperBody => l10n.bodyMetricsUpperBody,
      BodyMetricsGroup.arms => l10n.bodyMetricsArms,
      BodyMetricsGroup.legs => l10n.bodyMetricsLegs,
    };

/// A ratio's name, such as "Waist to Height".
String bodyRatioName(AppLocalizations l10n, BodyRatioKind kind) =>
    switch (kind) {
      BodyRatioKind.waistToHeight => l10n.bodyRatioWaistToHeight,
      BodyRatioKind.waistToHip => l10n.bodyRatioWaistToHip,
    };

/// A ratio to two decimal places, as Swift shows one: "0.44".
String ratioText(double ratio, String locale) =>
    NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 2,
    ).format(ratio);

/// A nutrition metric's card title (Swift `NutritionMetric.title`).
String nutritionMetricName(AppLocalizations l10n, NutritionMetric metric) =>
    switch (metric) {
      NutritionMetric.macros => l10n.progressMacros,
      NutritionMetric.calories => l10n.nutritionOverviewCalories,
      NutritionMetric.protein => l10n.progressProtein,
      NutritionMetric.fat => l10n.nutritionMacroFat,
      NutritionMetric.carbs => l10n.nutritionMacroCarbs,
      NutritionMetric.fiber => l10n.nutrientFiber,
      NutritionMetric.netCarbs => l10n.nutritionMetricNetCarbs,
      NutritionMetric.sugars => l10n.nutritionMetricSugars,
      NutritionMetric.fatMono => l10n.nutrientMonounsaturated,
      NutritionMetric.fatPoly => l10n.nutrientPolyunsaturated,
      NutritionMetric.fatSaturated => l10n.nutrientSaturated,
      NutritionMetric.thiamin => l10n.nutritionMetricThiamin,
      NutritionMetric.riboflavin => l10n.nutritionMetricRiboflavin,
      NutritionMetric.niacin => l10n.nutritionMetricNiacin,
      NutritionMetric.pantothenicAcid => l10n.nutritionMetricPantothenicAcid,
      NutritionMetric.vitaminB6 => l10n.nutritionMetricVitaminB6,
      NutritionMetric.vitaminB12 => l10n.nutritionMetricVitaminB12,
      NutritionMetric.folate => l10n.nutrientFolate,
      NutritionMetric.vitaminA => l10n.nutrientVitaminA,
      NutritionMetric.vitaminC => l10n.nutrientVitaminC,
      NutritionMetric.vitaminD => l10n.nutrientVitaminD,
      NutritionMetric.vitaminE => l10n.nutrientVitaminE,
      NutritionMetric.vitaminK => l10n.nutrientVitaminK,
      NutritionMetric.calcium => l10n.nutrientCalcium,
      NutritionMetric.copper => l10n.nutrientCopper,
      NutritionMetric.iron => l10n.nutrientIron,
      NutritionMetric.magnesium => l10n.nutrientMagnesium,
      NutritionMetric.manganese => l10n.nutrientManganese,
      NutritionMetric.phosphorus => l10n.nutrientPhosphorus,
      NutritionMetric.potassium => l10n.nutrientPotassium,
      NutritionMetric.selenium => l10n.nutrientSelenium,
      NutritionMetric.sodium => l10n.nutrientSodium,
      NutritionMetric.zinc => l10n.nutrientZinc,
      NutritionMetric.caffeine => l10n.nutrientCaffeine,
      NutritionMetric.cholesterol => l10n.nutrientCholesterol,
    };

/// A nutrition section's heading.
String nutritionSectionName(
  AppLocalizations l10n,
  NutritionMetricSection section,
) => switch (section) {
  NutritionMetricSection.macros => l10n.nutritionAnalyticsCaloriesAndMacros,
  NutritionMetricSection.carbs => l10n.nutritionOverviewCarbBreakdown,
  NutritionMetricSection.fats => l10n.nutritionOverviewFatBreakdown,
  NutritionMetricSection.vitamins => l10n.nutritionAnalyticsVitamins,
  NutritionMetricSection.minerals => l10n.nutritionAnalyticsMinerals,
  NutritionMetricSection.other => l10n.nutritionAnalyticsOther,
};

/// A nutrition metric's colour (Swift `NutritionMetric.chartColor`).
Color nutritionMetricColor(AppColors colors, NutritionMetric metric) =>
    switch (metric.section) {
      NutritionMetricSection.macros => switch (metric) {
        NutritionMetric.macros => colors.nutrition,
        NutritionMetric.calories => colors.calories,
        NutritionMetric.protein => colors.protein,
        NutritionMetric.fat => colors.fat,
        _ => colors.carbs,
      },
      NutritionMetricSection.carbs => colors.carbs,
      NutritionMetricSection.fats => colors.fat,
      NutritionMetricSection.vitamins => colors.vitamins,
      NutritionMetricSection.minerals => colors.minerals,
      NutritionMetricSection.other => colors.otherNutrients,
    };
