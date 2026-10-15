import 'package:compound/expenditure_metric/expenditure_metric.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart';
import 'package:compound/progress/progress.dart';
import 'package:compound/training_analytics/training_analytics.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The screens behind the Progress tab as the app declares them, starting
/// at [location], with the screens they open elsewhere stood in for by
/// their names.
GoRouter progressRouter(String location) => GoRouter(
  initialLocation: location,
  routes: [
    GoRoute(
      path: '/progress',
      builder: (_, _) => const Text('Progress screen'),
      routes: [
        ...progressRoutes,
        for (final (path, name) in [
          for (final metric in WeightMetric.values) (metric.path, metric.name),
          for (final metric in ExpenditureMetric.values)
            (metric.path, metric.name),
          (WorkoutMetricPage.path, WorkoutMetricPage.name),
          (WorkoutConsistencyPage.path, WorkoutConsistencyPage.name),
        ])
          _stub(path, name),
      ],
    ),
    ...progressRootRoutes,
    _stub(LogWeightPage.path, LogWeightPage.name),
    _stub(AddMealPage.path, AddMealPage.name),
  ],
);

GoRoute _stub(String path, String name) => GoRoute(
  path: path,
  name: name,
  builder: (_, state) => Text('$name screen ${state.extra ?? ''}'.trim()),
);
