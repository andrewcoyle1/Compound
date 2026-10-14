import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/bloc/app_bloc.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/nutrition.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/shell/shell.dart';
import 'package:compound/sign_in/sign_in.dart';
import 'package:compound/training/training.dart';
import 'package:compound/workout_history/workout_history.dart';
import 'package:compound/workout_session_detail/workout_session_detail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

class const App({
  required final AuthRepository authRepository,
  required final UserRepository userRepository,
  required final WorkoutSessionRepository workoutSessionRepository,
  required final NutritionRepository nutritionRepository,
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
      ],
      child: BlocProvider(
        create: (_) =>
            AppBloc(authRepository: authRepository)
              ..add(const AppUserSubscriptionRequested()),
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
      GoRoute(
        path: SignInPage.path,
        name: SignInPage.name,
        builder: (_, _) => const SignInPage(),
      ),
    ],
    redirect: (context, state) {
      final signedIn = context.read<AppBloc>().state is AppAuthenticated;
      final onSignIn = state.matchedLocation == SignInPage.path;
      if (!signedIn) return onSignIn ? null : SignInPage.path;
      return onSignIn ? AppTab.today.path : null;
    },
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
