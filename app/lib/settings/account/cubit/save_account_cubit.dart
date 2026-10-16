import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:user_repository/user_repository.dart';

/// Where Save Account is.
enum SaveAccountStatus {
  /// Waiting for a choice.
  idle,

  /// Apple's or Google's sheet is open, or the link is being made.
  inProgress,

  /// Linked: the screen closes.
  saved,

  /// The sign-in failed; the account is still anonymous.
  failure,
}

/// Saving an anonymous account by linking Apple or Google to it, from
/// Settings (Swift `SettingsPresenter.onSaveAccountPressed`, which opens
/// `AuthView`). [AuthRepository] links, so the uid and everything logged
/// under it carry over; the events are `AuthPresenter`'s.
///
/// Once linked, the profile is told: `is_anonymous`, `email` and
/// `auth_providers`, field by field. Swift never updates them after a link,
/// so its profile goes on saying anonymous (`swift-findings.md`). If the
/// provider already belonged to another account, the repository signs in to
/// that one instead and nothing is written to it.
class SaveAccountCubit extends Cubit<SaveAccountStatus> {
  new({required this._auth, required this._users, required this._analytics})
    : super(SaveAccountStatus.idle);

  final AuthRepository _auth;
  final UserRepository _users;
  final AnalyticsRepository _analytics;

  /// `AuthView_Appear`.
  void appeared() => _analytics.appear('AuthView');

  /// `AuthView_Disappear`.
  void disappeared() => _analytics.disappear('AuthView');

  /// Links Sign in with Apple (`Auth_AppleAuth_*`).
  Future<void> applePressed() => _link('Auth_AppleAuth', _auth.signInWithApple);

  /// Links Google (`Auth_GoogleAuth_*`).
  Future<void> googlePressed() =>
      _link('Auth_GoogleAuth', _auth.signInWithGoogle);

  Future<void> _link(String event, Future<void> Function() signIn) async {
    if (state == SaveAccountStatus.inProgress) return;
    final uid = _auth.currentUser?.uid;
    emit(SaveAccountStatus.inProgress);
    _analytics.analytic('${event}_Start');
    try {
      await signIn();
    } on SignInCancelled {
      emit(SaveAccountStatus.idle);
      return;
    } on Object catch (error) {
      _analytics.severe('${event}_Fail', error);
      emit(SaveAccountStatus.failure);
      return;
    }
    _analytics.analytic('${event}_Success');
    final user = _auth.currentUser;
    if (user != null && user.uid == uid && !user.isAnonymous) {
      try {
        await _users.updateUserFields(user.uid, [
          UserField.isAnonymous(false),
          if (user.email case final email?) UserField.email(email),
          UserField.authProviders([
            for (final provider in user.providers) provider.name,
          ]),
        ]);
      } on Object catch (error) {
        // Linked all the same: the profile only lags behind the account.
        _analytics.severe('Auth_UserLogin_Fail', error);
      }
    }
    emit(SaveAccountStatus.saved);
  }
}
