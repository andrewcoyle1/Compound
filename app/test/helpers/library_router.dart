import 'package:compound/create_exercise/create_exercise.dart';
import 'package:compound/training/training.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The Training tab's library routes as the app declares them, starting at
/// [location]. `/launcher` opens the exercise picker with [request] and
/// shows what it returned.
GoRouter libraryRouter(
  String location, {
  ExercisePickerRequest request = const ExercisePickerRequest(),
}) => GoRouter(
  initialLocation: location,
  routes: [
    GoRoute(
      path: '/training',
      builder: (_, _) => const TrainingPage(),
      routes: [
        GoRoute(
          path: WorkoutsPage.path,
          name: WorkoutsPage.name,
          builder: (_, _) => const WorkoutsPage(),
          routes: [
            GoRoute(
              path: WorkoutTemplateDetailPage.path,
              name: WorkoutTemplateDetailPage.name,
              builder: (_, state) => WorkoutTemplateDetailPage(
                workoutId: state
                    .pathParameters[WorkoutTemplateDetailPage.idParameter]!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: ExercisesPage.path,
          name: ExercisesPage.name,
          builder: (_, _) => const ExercisesPage(),
          routes: [
            GoRoute(
              path: ExerciseDetailPage.path,
              name: ExerciseDetailPage.name,
              builder: (_, state) => ExerciseDetailPage(
                exerciseId:
                    state.pathParameters[ExerciseDetailPage.idParameter]!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'history',
          name: 'workoutHistory',
          builder: (_, _) => const Text('History screen'),
        ),
      ],
    ),
    GoRoute(
      path: ExercisePickerPage.path,
      name: ExercisePickerPage.name,
      builder: (_, state) => ExercisePickerPage(
        request: switch (state.extra) {
          final ExercisePickerRequest request => request,
          _ => const ExercisePickerRequest(),
        },
      ),
    ),
    GoRoute(
      path: CreateExercisePage.path,
      name: CreateExercisePage.name,
      pageBuilder: (_, state) =>
          MaterialPage(key: state.pageKey, child: const CreateExercisePage()),
    ),
    GoRoute(
      path: '/launcher',
      builder: (_, _) => _Launcher(request: request),
    ),
  ],
);

class _Launcher extends StatefulWidget {
  const new({required this.request});

  final ExercisePickerRequest request;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  List<ExerciseModel>? _picked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () async {
              final picked = await ExercisePickerPage.show(
                context,
                request: widget.request,
              );
              setState(() => _picked = picked);
            },
            child: const Text('Pick'),
          ),
          Text('Picked: ${_picked?.map((e) => e.id).join(',')}'),
        ],
      ),
    );
  }
}
