import 'package:compound/l10n/l10n.dart';
import 'package:compound/sign_in/cubit/sign_in_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

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
    // Sign in with Apple is offered on iOS only until the Android web flow
    // is configured (plan.md: Apple arrives with iOS at M6).
    final showApple = Theme.of(context).platform == TargetPlatform.iOS;

    return BlocListener<SignInCubit, SignInStatus>(
      listenWhen: (_, status) => status == SignInStatus.failure,
      listener: (context, _) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.signInFailure))),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                const Spacer(),
                Text(
                  l10n.signInTitle,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                if (showApple)
                  FilledButton(
                    onPressed: enabled ? cubit.signInWithApple : null,
                    child: Text(l10n.signInWithAppleButton),
                  ),
                FilledButton(
                  onPressed: enabled ? cubit.signInWithGoogle : null,
                  child: Text(l10n.signInWithGoogleButton),
                ),
                TextButton(
                  onPressed: enabled ? cubit.signInAnonymously : null,
                  child: Text(l10n.signInAnonymouslyButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
