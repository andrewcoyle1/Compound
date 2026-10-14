import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/bloc/app_bloc.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/profile/profile.dart';
import 'package:compound/shell/shell.dart';
import 'package:compound/sign_in/sign_in.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:user_repository/user_repository.dart';

class const App({
  required final AuthRepository authRepository,
  required final UserRepository userRepository,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: userRepository),
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
                GoRoute(
                  path: tab.path,
                  name: tab.name,
                  builder: (_, _) => TabPlaceholderPage(tab: tab),
                ),
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
