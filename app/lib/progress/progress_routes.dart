import 'package:compound/log_measurement/log_measurement.dart';
import 'package:compound/progress/logic/body_metrics.dart';
import 'package:compound/progress/logic/nutrition_analytics.dart';
import 'package:compound/progress/view/body_metrics_pages.dart';
import 'package:compound/progress/view/nutrition_analytics_pages.dart';
import 'package:compound/progress/view/progress_metric_pages.dart';
import 'package:compound/progress_photos/progress_photos.dart';
import 'package:compound/widgets/half_sheet_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The screens behind the Progress tab's sections: Insights & Analytics,
/// Habits and their consistency grids, Nutrition and each nutrient, Body
/// Metrics and each metric, Goal Progress and Steps, each metric with its
/// All Recorded Data at `data`.
final progressRoutes = <RouteBase>[
  GoRoute(
    path: InsightsPage.path,
    name: InsightsPage.name,
    builder: (_, _) => const InsightsPage(),
  ),
  GoRoute(
    path: HabitsPage.path,
    name: HabitsPage.name,
    builder: (_, _) => const HabitsPage(),
  ),
  _metric(
    WeighInConsistencyPage.path,
    WeighInConsistencyPage.name,
    WeighInConsistencyPage.dataName,
    (_, {allData = false}) => WeighInConsistencyPage(allData: allData),
  ),
  _metric(
    FoodLoggingConsistencyPage.path,
    FoodLoggingConsistencyPage.name,
    FoodLoggingConsistencyPage.dataName,
    (_, {allData = false}) => FoodLoggingConsistencyPage(allData: allData),
  ),
  _metric(
    GoalProgressPage.path,
    GoalProgressPage.name,
    GoalProgressPage.dataName,
    (_, {allData = false}) => GoalProgressPage(allData: allData),
  ),
  _metric(
    StepsPage.path,
    StepsPage.name,
    StepsPage.dataName,
    (_, {allData = false}) => StepsPage(allData: allData),
  ),
  GoRoute(
    path: NutritionAnalyticsPage.path,
    name: NutritionAnalyticsPage.name,
    builder: (_, _) => const NutritionAnalyticsPage(),
    routes: [
      _metric(
        NutritionMetricPage.path,
        NutritionMetricPage.name,
        NutritionMetricPage.dataName,
        (state, {allData = false}) {
          final metric = NutritionMetric.tryParse(
            state.pathParameters[NutritionMetricPage.metricParameter],
          );
          // An unknown metric shows every metric instead.
          return metric == null
              ? const NutritionAnalyticsPage()
              : NutritionMetricPage(metric: metric, allData: allData);
        },
      ),
    ],
  ),
  GoRoute(
    path: BodyMetricsPage.path,
    name: BodyMetricsPage.name,
    builder: (_, _) => const BodyMetricsPage(),
    routes: [
      GoRoute(
        path: ProgressPhotosPage.path,
        name: ProgressPhotosPage.name,
        builder: (_, _) => const ProgressPhotosPage(),
        routes: [
          GoRoute(
            path: ProgressPhotoComparePage.path,
            name: ProgressPhotoComparePage.name,
            builder: (_, state) => switch (state.extra) {
              final ProgressPhotoComparison comparison =>
                ProgressPhotoComparePage(comparison: comparison),
              // Opened without its photos (a restored route): the photos.
              _ => const ProgressPhotosPage(),
            },
          ),
        ],
      ),
      _metric(
        BodyMetricDetailPage.path,
        BodyMetricDetailPage.name,
        BodyMetricDetailPage.dataName,
        (state, {allData = false}) => BodyMetricDetailPage.forId(
          state.pathParameters[BodyMetricDetailPage.metricParameter],
          allData: allData,
        ),
      ),
    ],
  ),
];

/// The logger for one circumference, over the tabs as Swift's half sheet;
/// an unknown circumference opens the waist's.
final progressRootRoutes = <RouteBase>[
  GoRoute(
    path: LogMeasurementPage.path,
    name: LogMeasurementPage.name,
    pageBuilder: (_, state) => HalfSheetPage(
      key: state.pageKey,
      child: LogMeasurementPage(
        kind:
            BodyMeasurementKind.tryParse(
              state.pathParameters[LogMeasurementPage.kindParameter],
            ) ??
            BodyMeasurementKind.waist,
      ),
    ),
  ),
];

/// A metric's route and its All Recorded Data at `data`.
GoRoute _metric(
  String path,
  String name,
  String dataName,
  Widget Function(GoRouterState state, {bool allData}) page,
) => GoRoute(
  path: path,
  name: name,
  builder: (_, state) => page(state),
  routes: [
    GoRoute(
      path: 'data',
      name: dataName,
      builder: (_, state) => page(state, allData: true),
    ),
  ],
);
