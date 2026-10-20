import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:health_repository/health_repository.dart';

/// The signed-in account's Apple Health or Health Connect imports.
final class const HealthState({
  /// Whose imports these are.
  final String? uid,

  /// Moves each time asking for step access failed after a tap: "Unable
  /// to Access Apple Health".
  final int stepsAccessFailures = 0,
}) extends Equatable {
  @override
  List<Object?> get props => [uid, stepsAccessFailures];
}

/// Apple Health and Health Connect for the signed-in account, app-wide, as
/// Swift's managers run their imports: steps, weigh-ins and food are
/// brought up to date at sign-in and again when a screen that shows them
/// appears, each after asking for its own access where Swift asks
/// (`StepsPresenter`, `ScaleWeightPresenter`, `VisualBodyFatPresenter`,
/// `NutritionPresenter`, `TodayPresenter.connectAppleHealth`). Health is
/// never essential: every read and write is guarded in the repository.
class HealthCubit extends Cubit<HealthState> {
  new({required this._health, required this._analytics})
    : super(const HealthState());

  final HealthRepository _health;
  final AnalyticsRepository _analytics;

  DateTime? _since;

  /// Someone else signed in, or out. A new account's imports run at once
  /// (`signIn` on Swift's steps, body and meal managers); steps and food
  /// before [since], the account's creation, are left out.
  void userChanged(String? uid, {DateTime? since}) {
    if (uid == state.uid) return;
    _since = since;
    emit(HealthState(uid: uid));
    if (uid == null) return;
    unawaited(_health.importSteps(uid, since: since));
    unawaited(_health.importBodyMeasurements(uid));
    unawaited(_health.importNutrition(uid, since: since));
  }

  /// Steps again, without asking (Today, each visit).
  Future<void> importSteps() async {
    final uid = state.uid;
    if (uid != null) await _health.importSteps(uid, since: _since);
  }

  /// The Steps screen appeared: asks for step access, then imports
  /// (`StepsPresenter.loadData`). A refusal still imports, which reads
  /// nothing.
  Future<void> stepsAppeared() async {
    final uid = state.uid;
    if (uid == null) return;
    if (await _health.isAvailable() &&
        !await _health.requestAuthorization(HealthScope.steps)) {
      _analytics.trackEvent(
        const AnalyticsEvent(
          'StepsView_LoadAuthorisation_Fail',
          type: LogType.warning,
        ),
      );
    }
    await _health.importSteps(uid, since: _since);
  }

  /// "Sync from Apple Health" on Steps (`StepsPresenter.onAddPressed`).
  Future<void> stepsSyncPressed() => _connectSteps(
    start: 'StepsView_Sync_Start',
    success: 'StepsView_Sync_Success',
    failure: 'StepsView_Sync_Fail',
    failureType: LogType.severe,
  );

  /// "Connect Apple Health" on Today's getting-started card
  /// (`TodayPresenter.connectAppleHealth`).
  Future<void> connectPressed() => _connectSteps(
    failure: 'TodayView_ConnectHealth_Fail',
    failureType: LogType.warning,
  );

  /// Asks for step access and imports. Refused, it says so and stops.
  Future<void> _connectSteps({
    required String failure,
    required LogType failureType,
    String? start,
    String? success,
  }) async {
    final uid = state.uid;
    if (uid == null) return;
    if (start != null) _analytics.analytic(start);
    if (await _health.isAvailable() &&
        !await _health.requestAuthorization(HealthScope.steps)) {
      _analytics.trackEvent(AnalyticsEvent(failure, type: failureType));
      if (!isClosed && state.uid == uid) {
        emit(
          HealthState(
            uid: uid,
            stepsAccessFailures: state.stepsAccessFailures + 1,
          ),
        );
      }
      return;
    }
    await _health.importSteps(uid, since: _since);
    if (success != null) _analytics.analytic(success);
  }

  /// Scale Weight or Visual Body Fat appeared, or Visual Body Fat's "Sync
  /// from Apple Health": asks for weight access as Swift's
  /// `requestBodyMeasurementHealthAccess`, then imports weigh-ins and body
  /// fat. Each run recounts all of Health's history, so it also picks up
  /// body fat granted after weight.
  Future<void> syncBody() async {
    final uid = state.uid;
    if (uid == null) return;
    await _health.requestAuthorization(HealthScope.bodyMeasurements);
    await _health.importBodyMeasurements(uid);
  }

  /// The Nutrition tab appeared: food logged in other apps comes in
  /// through Health (`NutritionPresenter.importFromAppleHealth`).
  Future<void> nutritionAppeared() async {
    final uid = state.uid;
    if (uid == null) return;
    if (await _health.isAvailable() &&
        !await _health.requestAuthorization(HealthScope.nutrition)) {
      _analytics.trackEvent(
        const AnalyticsEvent(
          'NutritionView_HealthAuthorisation_Fail',
          type: LogType.warning,
        ),
      );
    }
    await _health.importNutrition(uid, since: _since);
  }
}
