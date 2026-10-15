import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/bloc/app_bloc.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/launch/launch.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/nutrition/nutrition.dart';
import 'package:compound/onboarding/onboarding.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/progress/progress.dart';
import 'package:compound/shell/shell.dart';
import 'package:compound/sign_in/sign_in.dart';
import 'package:compound/today/today.dart';
import 'package:compound/training/training.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:compound/workout_history/workout_history.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

class const App({
  required final AuthRepository authRepository,
  required final UserRepository userRepository,
  required final WorkoutSessionRepository workoutSessionRepository,
  required final NutritionRepository nutritionRepository,
  required final BodyRepository bodyRepository,
  required final ProgramRepository programRepository,
  required final TrainingLibraryRepository trainingLibraryRepository,
  final AnalyticsRepository analyticsRepository = const AnalyticsRepository(),
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: userRepository),
        RepositoryProvider.value(value: workoutSessionRepository),
        RepositoryProvider.value(value: nutritionRepository),
        RepositoryProvider.value(value: bodyRepository),
        RepositoryProvider.value(value: programRepository),
        RepositoryProvider.value(value: trainingLibraryRepository),
        RepositoryProvider.value(value: analyticsRepository),
        RepositoryProvider(
          create: (_) => TrainingSetupService(
            programs: programRepository,
            library: trainingLibraryRepository,
            users: userRepository,
          ),
        ),
      ],
      child: BlocProvider(
        create: (_) => AppBloc(
          authRepository: authRepository,
          userRepository: userRepository,
          analyticsRepository: analyticsRepository,
        )..add(const AppUserSubscriptionRequested()),
        child: const AppView(),
      ),
    );
  }
}

class AppView extends StatefulWidget {
  const new({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  late final GoRouter _router = GoRouter(
    // A debug hook for screenshots and manual checks, e.g.
    // `--dart-define=INITIAL_LOCATION=/profile`.
    initialLocation: const String.fromEnvironment(
      'INITIAL_LOCATION',
      defaultValue: '/today',
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          for (final tab in AppTab.values)
            StatefulShellBranch(
              routes: [
                switch (tab) {
                  AppTab.today => GoRoute(
                    path: tab.path,
                    name: tab.name,
                    builder: (_, _) => const TodayPage(),
                  ),
                  AppTab.training => GoRoute(
                    path: tab.path,
                    name: tab.name,
                    builder: (_, _) => const TrainingPage(),
                    routes: [
                      GoRoute(
                        path: WorkoutHistoryPage.path,
                        name: WorkoutHistoryPage.name,
                        builder: (_, _) => const WorkoutHistoryPage(),
                        routes: [
                          GoRoute(
                            path: WorkoutSessionDetailPage.path,
                            name: WorkoutSessionDetailPage.name,
                            builder: (_, state) => WorkoutSessionDetailPage(
                              sessionId:
                                  state.pathParameters[WorkoutSessionDetailPage
                                      .sessionIdParameter]!,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  AppTab.nutrition => GoRoute(
                    path: tab.path,
                    name: tab.name,
                    builder: (_, _) => const NutritionPage(),
                  ),
                  AppTab.progress => GoRoute(
                    path: tab.path,
                    name: tab.name,
                    builder: (_, _) => const ProgressPage(),
                    routes: [
                      for (final metric in WeightMetric.values)
                        GoRoute(
                          path: metric.path,
                          name: metric.name,
                          builder: (_, _) => WeightMetricPage(metric: metric),
                          routes: [
                            GoRoute(
                              path: 'data',
                              name: metric.dataRouteName,
                              builder: (_, _) => WeightMetricPage(
                                metric: metric,
                                allData: true,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  _ => GoRoute(
                    path: tab.path,
                    name: tab.name,
                    builder: (_, _) => TabPlaceholderPage(tab: tab),
                  ),
                },
              ],
            ),
        ],
      ),
      // Over the tabs, as the Swift app's full-screen cover.
      GoRoute(
        path: ProfilePage.path,
        name: ProfilePage.name,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const ProfilePage(),
        ),
      ),
      // Over the tabs, as the Swift app's sheet.
      GoRoute(
        path: LogWeightPage.path,
        name: LogWeightPage.name,
        pageBuilder: (_, state) => MaterialPage(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const LogWeightPage(),
        ),
      ),
      GoRoute(
        path: SignInPage.path,
        name: SignInPage.name,
        builder: (_, _) => const SignInPage(),
      ),
      GoRoute(
        path: LaunchPage.path,
        name: LaunchPage.name,
        builder: (_, _) => const LaunchPage(),
      ),
      for (final route in OnboardingRoute.values)
        GoRoute(
          path: route.path,
          name: route.routeName,
          builder: (_, _) => switch (route) {
            OnboardingRoute.accountSetup => const AccountSetupPage(),
            OnboardingRoute.healthDisclaimer => const HealthDisclaimerPage(),
            OnboardingRoute.goal => const GoalSetupPage(),
            OnboardingRoute.gymProfile => const GymSetupPage(),
            OnboardingRoute.program => const ProgramSetupPage(),
            OnboardingRoute.diet => const DietSetupPage(),
          },
        ),
    ],
    redirect: (context, state) =>
        appRedirect(context.read<AppBloc>().state, state.uri),
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppState>(
      listener: (_, _) => _router.refresh(),
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router,
      ),
    );
  }
}

/// Where the router sends [location] for [state], or null to stay: signed
/// out to sign-in; while the profile loads (or can't be read) to the launch
/// screen, remembering where the user was going; during onboarding to the
/// screen of the step the profile resumes at (`OnboardingStepRouter`); and
/// once onboarded, away from sign-in, launch and onboarding to the tabs.
String? appRedirect(AppState state, Uri location) {
  final path = location.path;
  final onSignIn = path == SignInPage.path;
  final onLaunch = path == LaunchPage.path;
  if (state is! AppAuthenticated) return onSignIn ? null : SignInPage.path;
  if (state.profileStatus != AppProfileStatus.ready) {
    if (onLaunch) return null;
    return Uri(
      path: LaunchPage.path,
      queryParameters: onSignIn || path.startsWith(onboardingPath)
          ? null
          : {LaunchPage.fromParameter: location.toString()},
    ).toString();
  }
  final step = state.onboardingStep;
  if (step != null) {
    final target = onboardingRoute(step)!.path;
    return path == target ? null : target;
  }
  if (onLaunch) {
    return location.queryParameters[LaunchPage.fromParameter] ??
        AppTab.today.path;
  }
  return onSignIn || path.startsWith(onboardingPath) ? AppTab.today.path : null;
}
