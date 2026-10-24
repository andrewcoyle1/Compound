import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:purchases_repository/purchases_repository.dart';

/// Whether the coach shows: it is premium only, and Settings has a switch
/// for it.
final class const CoachAccess({
  /// Whether the user is treated as a subscriber.
  final bool premium = true,

  /// The Coach switch in Settings.
  final bool enabled = true,
}) extends Equatable {
  /// Creates a [CoachAccess].
  this;

  /// The coach is on: Today is its day chat, and Ask Coach buttons show.
  bool get isOn => premium && enabled;

  @override
  List<Object?> get props => [premium, enabled];
}

/// The one place the app reads whether the coach is on, followed live: a
/// purchase, or the switch turned on another device, changes it at once.
class CoachAccessCubit extends Cubit<CoachAccess> {
  new({
    required this._coach,
    required this._purchases,
    required this._analytics,
  }) : super(CoachAccess(premium: _purchases.state.isPremiumWith())) {
    _premium = _purchases.states.listen(
      (purchases) => emit(
        CoachAccess(premium: purchases.isPremiumWith(), enabled: state.enabled),
      ),
    );
  }

  final CoachRepository _coach;
  final PurchasesRepository _purchases;
  final AnalyticsRepository _analytics;
  late final StreamSubscription<PurchasesState> _premium;
  StreamSubscription<bool>? _enabled;
  String? _uid;

  /// Follows [uid]'s switch; signed out, it reads as on.
  void userChanged(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    unawaited(_enabled?.cancel());
    _enabled = null;
    emit(CoachAccess(premium: state.premium));
    if (uid == null) return;
    _enabled = _coach
        .watchEnabled(uid)
        .listen(
          (enabled) =>
              emit(CoachAccess(premium: state.premium, enabled: enabled)),
          onError: (Object _) {},
        );
  }

  /// The switch in Settings. Off hides the coach; consent and chats stay.
  Future<void> enabledChanged({required bool enabled}) async {
    final uid = _uid;
    if (uid == null) return;
    _analytics.analytic('SettingsView_Coach_Toggle', {'enabled': enabled});
    try {
      await _coach.setEnabled(uid, enabled: enabled);
    } on Object catch (error) {
      _analytics.severe('SettingsView_Coach_Toggle_Fail', error);
    }
  }

  @override
  Future<void> close() async {
    await _premium.cancel();
    await _enabled?.cancel();
    await super.close();
  }
}
