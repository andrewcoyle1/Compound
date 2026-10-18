import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:connectivity_repository/connectivity_repository.dart';

/// "You're offline", app-wide (Swift's `ensureOnline` and
/// `showOfflineAlert`): counts the actions not started for want of a
/// network, so the app shows the alert for each, and records
/// `Offline_ActionBlocked`.
class OfflineAlertCubit extends Cubit<int> {
  new({
    required ConnectivityRepository connectivity,
    required AnalyticsRepository analytics,
  }) : super(0) {
    _subscription = connectivity.blocked.listen((_) {
      analytics.trackEvent(const AnalyticsEvent('Offline_ActionBlocked'));
      emit(state + 1);
    });
  }

  late final StreamSubscription<void> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
