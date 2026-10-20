import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:user_repository/user_repository.dart';

/// Where deleting the account stands.
enum DeleteAccountStatus {
  /// Waiting for the person to confirm.
  idle,

  /// Signing in again and deleting.
  deleting,

  /// Gone.
  deleted,

  /// Deletion failed; the account is kept.
  failure,
}

/// The Delete Account confirmation (Swift `DeleteAccountPresenter`).
///
/// Deleting is `CoreInteractor.deleteAccount`'s order: sign in again (not
/// for an anonymous account), delete the profile while the rules still let
/// this user, which starts the `onUserDeleted` function that removes the
/// rest, then delete the sign-in account.
///
/// The profile vanishing and the account signing out both move the router
/// on (to the launch screen, then sign-in), which closes this screen and
/// this cubit before deletion finishes. So [deletePressed] also calls back
/// on success, for the view to announce it somewhere that outlives the
/// screen.
class DeleteAccountCubit extends Cubit<DeleteAccountStatus> {
  new({
    required this._authRepository,
    required this._userRepository,
    required this._analytics,
    required this._uid,
  }) : super(DeleteAccountStatus.idle);

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final AnalyticsRepository _analytics;
  final String _uid;

  static const _screen = 'DeleteAccountView';

  /// `DeleteAccountView_Appear`, as a screen view.
  void appeared() => _analytics.appear(_screen);

  /// `DeleteAccountView_Disappear`.
  void disappeared() => _analytics.disappear(_screen);

  /// `DeleteAccountView_ManageSubscription_Press`, before the store's
  /// subscription page opens.
  void manageSubscriptionPressed() =>
      _analytics.analytic('${_screen}_ManageSubscription_Press');

  /// Deletes the account. The `Settings_DeleteAccount_*` names are the ones
  /// Swift's old alert logged, kept so the deletion funnel carries on.
  /// [onDeleted] runs once the account is gone, even after this cubit has
  /// closed. Dismissing the sign-in goes back to [DeleteAccountStatus.idle].
  Future<void> deletePressed({void Function()? onDeleted}) async {
    if (state == DeleteAccountStatus.deleting ||
        state == DeleteAccountStatus.deleted) {
      return;
    }
    _analytics.analytic('Settings_DeleteAccount_StartConfirm');
    _emit(DeleteAccountStatus.deleting);
    DeleteAccountStatus outcome;
    try {
      await _authRepository.deleteAccount(
        beforeDelete: () => _userRepository.deleteUser(_uid),
      );
      _analytics.analytic('Settings_DeleteAccount_Success');
      outcome = DeleteAccountStatus.deleted;
      onDeleted?.call();
    } on SignInCancelled {
      // Closing the sign-in sheet keeps the account; nothing went wrong.
      _analytics.analytic('Settings_DeleteAccount_Cancelled');
      outcome = DeleteAccountStatus.idle;
    } on Object catch (error) {
      _analytics.severe('Settings_DeleteAccount_Fail', error);
      outcome = DeleteAccountStatus.failure;
    }
    _emit(outcome);
  }

  void _emit(DeleteAccountStatus status) {
    if (!isClosed) emit(status);
  }
}
