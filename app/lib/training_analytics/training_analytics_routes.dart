import 'package:compound/training_analytics/training_analytics.dart';
import 'package:compound_models/compound_models.dart' show Muscles;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The training analytics screens under the Progress tab: Exercises and
/// each exercise's 1RM, Muscle Groups and each muscle, Muscle Balance,
/// Workouts and workout consistency, each metric with its All Recorded
/// Data at `data`.
final trainingAnalyticsRoutes = <RouteBase>[
  GoRoute(
    path: ExerciseAnalyticsPage.path,
    name: ExerciseAnalyticsPage.name,
    builder: (_, _) => const ExerciseAnalyticsPage(),
    routes: [
      GoRoute(
        path: ExerciseOneRepMaxPage.path,
        name: ExerciseOneRepMaxPage.name,
        builder: (_, state) => ExerciseOneRepMaxPage(
          exerciseId: state.pathParameters[ExerciseOneRepMaxPage.idParameter]!,
        ),
        routes: [
          GoRoute(
            path: 'data',
            name: ExerciseOneRepMaxPage.dataName,
            builder: (_, state) => ExerciseOneRepMaxPage(
              exerciseId:
                  state.pathParameters[ExerciseOneRepMaxPage.idParameter]!,
              allData: true,
            ),
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: MuscleGroupsPage.path,
    name: MuscleGroupsPage.name,
    builder: (_, _) => const MuscleGroupsPage(),
    routes: [
      GoRoute(
        path: MuscleGroupDetailPage.path,
        name: MuscleGroupDetailPage.name,
        builder: (_, state) => _muscle(state),
        routes: [
          GoRoute(
            path: 'data',
            name: MuscleGroupDetailPage.dataName,
            builder: (_, state) => _muscle(state, allData: true),
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: MuscleBalancePage.path,
    name: MuscleBalancePage.name,
    builder: (_, _) => const MuscleBalancePage(),
  ),
  GoRoute(
    path: WorkoutMetricPage.path,
    name: WorkoutMetricPage.name,
    builder: (_, _) => const WorkoutMetricPage(),
    routes: [
      GoRoute(
        path: 'data',
        name: WorkoutMetricPage.dataName,
        builder: (_, _) => const WorkoutMetricPage(allData: true),
      ),
    ],
  ),
  GoRoute(
    path: WorkoutConsistencyPage.path,
    name: WorkoutConsistencyPage.name,
    builder: (_, _) => const WorkoutConsistencyPage(),
    routes: [
      GoRoute(
        path: 'data',
        name: WorkoutConsistencyPage.dataName,
        builder: (_, _) => const WorkoutConsistencyPage(allData: true),
      ),
    ],
  ),
];

/// The muscle the path names; an unknown one shows every muscle instead.
Widget _muscle(GoRouterState state, {bool allData = false}) {
  final value = state.pathParameters[MuscleGroupDetailPage.muscleParameter];
  final muscle = Muscles.values.where((m) => m.value == value).firstOrNull;
  return muscle == null
      ? const MuscleGroupsPage()
      : MuscleGroupDetailPage(muscle: muscle, allData: allData);
}
