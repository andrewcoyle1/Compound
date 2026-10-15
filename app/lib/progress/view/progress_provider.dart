import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/progress/bloc/progress_bloc.dart';
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// Provides a [ProgressBloc] for one of the screens behind the Progress tab
/// to [child], named [screen] for its `_Appear` and `_Disappear` events
/// (with [parameters]), following the signed-in user's data.
class ProgressProvider extends StatelessWidget {
  const new({
    required this.screen,
    required this.child,
    this.parameters,
    super.key,
  });

  /// The Swift view's analytics name, such as `BodyMetricsView`.
  final String screen;

  /// Its analytics parameters, if any.
  final Map<String, Object?>? parameters;

  /// The screen.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    final analytics = context.read<AnalyticsRepository>();
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    return BlocProvider(
      create: (context) => ProgressBloc(
        workoutSessionRepository: context.read<WorkoutSessionRepository>(),
        nutritionRepository: context.read<NutritionRepository>(),
        bodyRepository: context.read<BodyRepository>(),
        userRepository: context.read<UserRepository>(),
        analyticsRepository: analytics,
        trainingLibraryRepository: context.read<TrainingLibraryRepository>(),
        checkInRepository: context.read<CheckInRepository>(),
        uid: state.user.uid,
        firstWeekday: firstDay == 0 ? DateTime.sunday : firstDay,
        screen: screen,
        parameters: parameters,
      )..add(const ProgressSubscriptionRequested()),
      child: OnDispose(
        onDispose: () => analytics.disappear(screen, parameters),
        child: child,
      ),
    );
  }
}
