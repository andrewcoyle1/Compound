import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/create_exercise/view/create_exercise_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/cubit/exercise_list_cubit.dart';
import 'package:compound/training_library/view/exercise_detail_page.dart';
import 'package:compound/training_library/view/exercise_list.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The exercise library, pushed from the Training tab's Library (Swift
/// `ExercisesView`), with Create Exercise atop the user's own.
class ExercisesPage extends StatelessWidget {
  const new({super.key});

  /// The path under the Training tab.
  static const path = 'exercises';

  /// The route name.
  static const name = 'exercises';

  @override
  Widget build(BuildContext context) {
    // The router only shows this page while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return TrainingLibraryProvider(
      uid: state.user.uid,
      child: BlocProvider(
        create: (context) =>
            ExerciseListCubit(analytics: context.read<AnalyticsRepository>())
              ..appeared('ExercisesView'),
        child: const ExercisesView(),
      ),
    );
  }
}

class ExercisesView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.trainingExercisesRow)),
      body: SafeArea(
        bottom: false,
        child: ExerciseList(
          onExercisePressed: (exercise) => unawaited(
            context.pushNamed(
              ExerciseDetailPage.name,
              pathParameters: {ExerciseDetailPage.idParameter: exercise.id},
            ),
          ),
          onCreateExercise: () => unawaited(CreateExercisePage.open(context)),
        ),
      ),
    );
  }
}
