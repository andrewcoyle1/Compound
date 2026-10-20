import 'dart:async';

import 'package:ab_test_repository/ab_test_repository.dart';
import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';

/// The A/B tests this user is in (Swift `ABTestManager`), for the whole app.
///
/// It starts from what the repository has, sends the assignments as user
/// properties (Swift's names), and fetches the latest once; a Developer
/// Settings override made while that fetch is in flight wins over it.
class AbTestsCubit extends Cubit<ActiveAbTests> {
  new({required this._repository, required this._analytics})
    : super(_repository.activeTests);

  final AbTestRepository _repository;
  final AnalyticsRepository _analytics;

  /// Set by [override], so a fetch started earlier cannot undo it.
  bool _hasOverridden = false;

  /// At launch: the user properties, then the fetch
  /// (`ABMan_FetchRemote_Success` or `_Fail`).
  Future<void> started() async {
    _analytics.addUserProperties(state.eventParameters);
    try {
      final fetched = await _repository.fetch();
      _analytics.analytic('ABMan_FetchRemote_Success');
      if (_hasOverridden || isClosed) return;
      emit(fetched);
      _analytics.addUserProperties(fetched.eventParameters);
    } on Object catch (error) {
      _analytics.severe('ABMan_FetchRemote_Fail', error);
    }
  }

  /// Developer Settings' override (Swift's `DevSettingsView_OverrideTest_*`
  /// events, since that screen is its only caller). Nothing happens when
  /// [tests] are the current ones. A repository that refuses (Remote Config,
  /// production only, where Developer Settings doesn't exist) leaves the
  /// tests as they were.
  void override(ActiveAbTests tests) {
    if (tests == state) return;
    _analytics.analytic('DevSettingsView_OverrideTest_Start');
    try {
      _repository.save(tests);
    } on Object catch (error) {
      _analytics.severe('DevSettingsView_OverrideTest_Fail', error);
      return;
    }
    _hasOverridden = true;
    emit(_repository.activeTests);
    _analytics
      ..addUserProperties(state.eventParameters)
      ..analytic('DevSettingsView_OverrideTest_Success');
  }
}
