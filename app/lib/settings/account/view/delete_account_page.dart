import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/settings/account/cubit/delete_account_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

/// The Delete Account confirmation (Swift `DeleteAccountView`): what is
/// deleted, the subscription it does not cancel, and the button.
///
/// Swift then shows "Account Deleted" in place with a Done button. Here the
/// router leaves for sign-in the moment the account is gone, taking this
/// screen with it, so the confirmation is a snack bar on the app's root
/// messenger, which outlives the route change and shows over sign-in.
class DeleteAccountPage extends StatelessWidget {
  const new({super.key});

  /// Under Settings: `/profile/settings/delete-account`.
  static const path = 'delete-account';
  static const name = 'settingsDeleteAccount';

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => DeleteAccountCubit(
        authRepository: context.read<AuthRepository>(),
        userRepository: context.read<UserRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        uid: state.user.uid,
      )..appeared(),
      child: DeleteAccountView(isAnonymous: state.user.isAnonymous),
    );
  }
}

class DeleteAccountView extends StatefulWidget {
  const new({required this.isAnonymous, super.key});

  /// An anonymous account has nothing to sign in again with.
  final bool isAnonymous;

  @override
  State<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<DeleteAccountView> {
  late final DeleteAccountCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<DeleteAccountCubit>();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    super.dispose();
  }

  Future<void> _delete() {
    final l10n = context.l10n;
    // Taken now: by the time deletion finishes this screen is gone.
    final messenger = ScaffoldMessenger.of(context);
    return _cubit.deletePressed(
      onDeleted: () => messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.deleteAccountDeleted}. ${l10n.deleteAccountDeletedMessage}',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = context.watch<DeleteAccountCubit>().state;
    final deleting = status == DeleteAccountStatus.deleting;
    return BlocListener<DeleteAccountCubit, DeleteAccountStatus>(
      listenWhen: (_, current) => current == DeleteAccountStatus.failure,
      listener: (context, _) => showAdaptiveDialog<void>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: Text(l10n.deleteAccountFailedTitle),
          content: Text(l10n.deleteAccountFailedMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.settingsOk),
            ),
          ],
        ),
      ),
      child: PopScope(
        canPop: !deleting,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.settingsDeleteAccount),
            automaticallyImplyLeading: !deleting,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.l),
              children: [
                AppSection(
                  header: l10n.deleteAccountWhatIsDeleted,
                  footer: l10n.deleteAccountWhatIsDeletedFooter,
                  children: [
                    AppListRow(
                      title: l10n.deleteAccountItemProfile,
                      icon: AppSymbols.profile,
                    ),
                    AppListRow(
                      title: l10n.deleteAccountItemWorkouts,
                      icon: AppSymbols.workout,
                    ),
                    AppListRow(
                      title: l10n.deleteAccountItemMeals,
                      icon: AppSymbols.meal,
                    ),
                    AppListRow(
                      title: l10n.deleteAccountItemBody,
                      icon: AppSymbols.measurement,
                    ),
                    AppListRow(
                      title: l10n.deleteAccountItemSocial,
                      icon: AppSymbols.friends,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                // Swift's Manage Subscription row opens Apple's sheet; the
                // app has no store sheet yet, so this says where to go.
                AppSection(
                  header: l10n.deleteAccountSubscriptionHeader,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.l),
                      child: Text(
                        l10n.deleteAccountSubscriptionMessage,
                        style: AppTextStyles.rowDetail,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                AppSection(
                  footer: widget.isAnonymous
                      ? null
                      : l10n.deleteAccountSignInAgain,
                  children: [
                    if (deleting)
                      const Padding(
                        padding: EdgeInsets.all(AppSpacing.l),
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      )
                    else
                      AppListRowButton(
                        title: l10n.settingsDeleteAccount,
                        accessory: null,
                        tint: Theme.of(context).colorScheme.error,
                        onPressed: _delete,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
