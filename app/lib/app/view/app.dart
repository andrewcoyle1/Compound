import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/bloc/app_bloc.dart';
import 'package:compound/home/home.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/sign_in/sign_in.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class const App({required final AuthRepository authRepository, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: authRepository,
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
    routes: [
      GoRoute(
        path: HomePage.path,
        name: HomePage.name,
        builder: (_, _) => const HomePage(),
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
      return onSignIn ? HomePage.path : null;
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
