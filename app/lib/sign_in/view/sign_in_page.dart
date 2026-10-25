import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/sign_in/cubit/sign_in_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SignInPage extends StatelessWidget {
  const new({super.key});

  static const path = '/sign-in';
  static const name = 'signIn';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SignInCubit(authRepository: context.read()),
      child: const SignInView(),
    );
  }
}

class SignInView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.watch<SignInCubit>().state;
    final cubit = context.read<SignInCubit>();
    final enabled = status != SignInStatus.inProgress;

    return BlocListener<SignInCubit, SignInStatus>(
      listenWhen: (_, status) => status == SignInStatus.failure,
      listener: (context, _) => showAppSnackBar(
        context,
        l10n.signInFailure,
        style: AppSnackBarStyle.error,
      ),
      child: AppScaffold(
        body: SafeArea(
          // Scrolls only when the text is too large for one screen.
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: AppSpacing.m,
                    children: [
                      const Spacer(),
                      // Capped as a large title is, so a long word is
                      // never broken across lines.
                      MediaQuery.withClampedTextScaling(
                        maxScaleFactor: AppScaffold.largeTitleMaxTextScale,
                        child: Semantics(
                          header: true,
                          child: Text(
                            l10n.signInTitle,
                            style: AppTextStyles.display,
                          ),
                        ),
                      ),
                      // What signing in gives (HIG, Sign in with Apple).
                      Text(
                        l10n.signInSubtitle,
                        style: AppTextStyles.rowTitle.secondary(context),
                      ),
                      const Spacer(flex: 2),
                      // Native on iOS, Firebase's web flow on Android. Both
                      // keep their makers' required look, so no volt here.
                      AppSignInWithAppleButton(
                        label: l10n.signInWithAppleButton,
                        onPressed: enabled ? cubit.signInWithApple : null,
                      ),
                      AppSignInWithGoogleButton(
                        label: l10n.signInWithGoogleButton,
                        onPressed: enabled ? cubit.signInWithGoogle : null,
                      ),
                      AppCtaButton(
                        label: l10n.signInAnonymouslyButton,
                        variant: AppCtaVariant.plain,
                        onPressed: enabled ? cubit.signInAnonymously : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
