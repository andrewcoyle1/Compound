import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/account/cubit/save_account_cubit.dart';
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:user_repository/user_repository.dart';

/// Saving an anonymous account (Swift's `AuthView`, opened by Settings'
/// Save Account): Apple or Google is linked to it, and the screen closes
/// once it is.
class SaveAccountPage extends StatelessWidget {
  const new({super.key});

  /// Under Settings: `/profile/settings/save-account`.
  static const path = 'save-account';
  static const name = 'settingsSaveAccount';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SaveAccountCubit(
        auth: context.read<AuthRepository>(),
        users: context.read<UserRepository>(),
        analytics: context.read<AnalyticsRepository>(),
      )..appeared(),
      child: const SaveAccountView(),
    );
  }
}

class SaveAccountView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SaveAccountCubit>();
    final busy = context.select<SaveAccountCubit, bool>(
      (cubit) => cubit.state == SaveAccountStatus.inProgress,
    );
    return BlocListener<SaveAccountCubit, SaveAccountStatus>(
      listener: (context, status) {
        switch (status) {
          case SaveAccountStatus.saved:
            context.pop();
          case SaveAccountStatus.failure:
            showAppSnackBar(
              context,
              l10n.signInFailure,
              style: AppSnackBarStyle.error,
            );
          case SaveAccountStatus.idle || SaveAccountStatus.inProgress:
            break;
        }
      },
      child: OnDispose(
        onDispose: cubit.disappeared,
        child: AppScaffold(
          appBar: AppBar(title: Text(l10n.settingsSaveAccount)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                Text(l10n.saveAccountMessage, style: AppTextStyles.rowTitle),
              ],
            ),
          ),
          bottomNavigationBar: AppBottomCta(
            children: [
              AppSignInWithAppleButton(
                label: l10n.signInWithAppleButton,
                isLoading: busy,
                onPressed: cubit.applePressed,
              ),
              AppSignInWithGoogleButton(
                label: l10n.signInWithGoogleButton,
                isLoading: busy,
                onPressed: cubit.googlePressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
