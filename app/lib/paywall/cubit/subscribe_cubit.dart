import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/paywall/paywall_exits.dart';

/// "Why Subscribe?" (Swift `SubscriptionPresenter`), with its event names.
/// The state counts failed sign-outs, for the alert.
class SubscribeCubit extends Cubit<int> {
  new({required this._auth, required this._analytics}) : super(0);

  final AuthRepository _auth;
  final AnalyticsRepository _analytics;

  /// Swift logs Appear and Disappear as `SubscriptionView`, and the rest as
  /// `SubscriptionInfoView`.
  static const _screen = 'SubscriptionInfoView';

  /// `SubscriptionView_Appear`.
  void appeared() => _analytics.appear('SubscriptionView');

  /// `SubscriptionView_Disappear`.
  void disappeared() => _analytics.disappear('SubscriptionView');

  /// `SubscriptionInfoView_Navigate`, before the paywall opens.
  void continuePressed() => _analytics.info('${_screen}_Navigate');

  /// `SubscriptionInfoView_Account_Press`, before Edit Profile opens.
  void accountPressed() => accountPressedFrom(_analytics, _screen);

  /// Signs out; the router then goes to sign-in.
  Future<void> signOutPressed() async {
    if (!await signOutFrom(_screen, auth: _auth, analytics: _analytics)) {
      if (!isClosed) emit(state + 1);
    }
  }
}
