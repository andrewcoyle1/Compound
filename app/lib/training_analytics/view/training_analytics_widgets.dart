import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:compound/training_analytics/bloc/training_analytics_bloc.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart'
    show UnitPreferenceStore;
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// Provides a [TrainingAnalyticsBloc] for [screen] to [child], following
/// the signed-in user's data, and logs the screen's `_Disappear` when it
/// leaves.
class TrainingAnalyticsProvider extends StatelessWidget {
  const new({
    required this.screen,
    required this.child,
    this.parameters,
    super.key,
  });

  /// The screen, for its analytics.
  final TrainingAnalyticsScreen screen;

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
    return BlocProvider(
      create: (context) => TrainingAnalyticsBloc(
        workoutSessionRepository: context.read<WorkoutSessionRepository>(),
        trainingLibraryRepository: context.read<TrainingLibraryRepository>(),
        userRepository: context.read<UserRepository>(),
        analyticsRepository: analytics,
        uid: state.user.uid,
        screen: screen,
        parameters: parameters,
        units: context.read<UnitPreferenceStore>(),
      )..add(const TrainingAnalyticsSubscriptionRequested()),
      child: OnDispose(
        onDispose: () => analytics.disappear(screen.analyticsName, parameters),
        child: child,
      ),
    );
  }
}

/// The body for each status: a spinner, the failure message, or [loaded].
class TrainingAnalyticsBody extends StatelessWidget {
  const new({required this.title, required this.loaded, super.key});

  /// The screen's name, for the failure message.
  final String title;

  /// The screen once the sessions have arrived.
  final Widget Function(TrainingAnalyticsState state) loaded;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingAnalyticsBloc>().state;
    return switch (state.status) {
      TrainingAnalyticsStatus.loading => AppLoadingView(
        label: context.l10n.launchLoading,
      ),
      TrainingAnalyticsStatus.failure => AnalyticsMessage(
        title: title,
        message: context.l10n.trainingAnalyticsLoadFailure,
      ),
      TrainingAnalyticsStatus.loaded => loaded(state),
    };
  }
}

/// An empty or failed state (Swift's `ContentUnavailableView`): the
/// analytics glyph, the metric's name, a line saying why and, when given,
/// a way to start a workout so it is not a dead end.
class AnalyticsMessage extends StatelessWidget {
  const new({
    required this.title,
    required this.message,
    this.offersWorkout = false,
    super.key,
  });

  /// The metric's name.
  final String title;

  /// Why there is nothing to show.
  final String message;

  /// Whether to offer Start Workout.
  final bool offersWorkout;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: AppSymbols.analytics,
    title: title,
    description: message,
    actionLabel: offersWorkout ? context.l10n.startWorkout : null,
    onAction: offersWorkout ? () => openWorkouts(context) : null,
  );
}

/// Opens the workouts list on the Training tab: sets and 1RMs come from
/// training (Swift `showWorkoutsView`).
void openWorkouts(BuildContext context) =>
    unawaited(Future.sync(() => context.goNamed(WorkoutsPage.name)));

/// The app bar's Start Workout action.
class StartWorkoutButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => AppToolbarButton(
    icon: AppSymbols.start,
    semanticLabel: context.l10n.startWorkout,
    onPressed: () => openWorkouts(context),
  );
}

/// A section's title, with the method's info button and a See All action
/// at its trailing edge when given (Swift `SectionHeaderView`,
/// `MethodInfoHeader`).
class AnalyticsSectionHeader extends StatelessWidget {
  const new({required this.title, this.info, this.onSeeAll, super.key});

  /// The section's name.
  final String title;

  /// The method behind its figures.
  final MethodInfo? info;

  /// Opens the section's own screen.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final info = this.info;
    final onSeeAll = this.onSeeAll;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.l),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppTextStyles.sectionTitle.secondary(context),
              ),
            ),
          ),
          if (info != null) MethodInfoButton(info),
          if (onSeeAll != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.l),
              child: AppChip(label: context.l10n.seeAll, onPressed: onSeeAll),
            ),
        ],
      ),
    );
  }
}

/// "1 set", "12 sets", "2.5 sets" (Swift `Format.sets`): a fractional
/// count is always plural.
String setsText(AppLocalizations l10n, double sets, String locale) =>
    sets == sets.roundToDouble()
    ? l10n.setCount(sets.round())
    : l10n.setCountDecimal(AppFormat.setCount(sets, locale: locale));
