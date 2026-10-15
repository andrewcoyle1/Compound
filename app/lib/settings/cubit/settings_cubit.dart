import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';

/// How an account signs in, for Settings' Sign-In Method row (Swift
/// `SettingsPresenter.signInMethod`).
enum SignInMethod {
  /// Anonymous: nothing to sign in again with.
  notSaved,

  /// Sign in with Apple.
  apple,

  /// Google.
  google,

  /// Linked to neither (no such account today).
  unknown;

  /// Apple before Google, as Swift checks them.
  factory of(AuthUser user) {
    if (user.isAnonymous) return notSaved;
    if (user.providers.contains(SignInProvider.apple)) return apple;
    if (user.providers.contains(SignInProvider.google)) return google;
    return unknown;
  }
}

/// What the Settings screen has to say beyond its rows: whether signing out
/// just failed.
enum SettingsStatus {
  /// Nothing to report.
  idle,

  /// Signing out is under way.
  signingOut,

  /// Signing out failed; the user is still signed in.
  signOutFailure,
}

/// The Settings list behind the profile's gear (Swift `SettingsPresenter`):
/// its analytics, with Swift's event names, and signing out.
class SettingsCubit extends Cubit<SettingsStatus> {
  new({required this._analytics, required this._auth})
    : super(SettingsStatus.idle);

  final AnalyticsRepository _analytics;
  final AuthRepository _auth;

  /// `ProfileView_Appear`: the screen's Swift name.
  void appeared() => _analytics.appear('ProfileView');

  /// `ProfileView_Disappear`.
  void disappeared() => _analytics.disappear('ProfileView');

  /// `ProfileView_Support_Press`.
  void supportPressed() => _analytics.analytic('ProfileView_Support_Press');

  /// `ProfileView_NotificationSettings_Press`.
  void notificationSettingsPressed() =>
      _analytics.analytic('ProfileView_NotificationSettings_Press');

  /// `Settings_DeleteAccount_Start`: the confirmation screen opens, and
  /// nothing is deleted yet.
  void deleteAccountPressed() =>
      _analytics.analytic('Settings_DeleteAccount_Start');

  /// Signs out; the router then leaves for sign-in. On failure the user
  /// stays signed in and the screen says so.
  Future<void> signOutPressed() async {
    if (state == SettingsStatus.signingOut) return;
    emit(SettingsStatus.signingOut);
    _analytics.analytic('Settings_SignOut_Start');
    try {
      await _auth.signOut();
      _analytics.analytic('Settings_SignOut_Success');
      emit(SettingsStatus.idle);
    } on Object catch (error) {
      _analytics.severe('Settings_SignOut_Fail', error);
      emit(SettingsStatus.signOutFailure);
    }
  }
}
