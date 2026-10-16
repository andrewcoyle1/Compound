import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

/// What the developer tools show beyond the signed-in user.
final class const DevSettingsState({
  /// "Simulate Premium": null when the store is not the fake, so there is
  /// nothing to simulate.
  final bool? simulatePremium,

  /// The user's own exercises and workout templates, beside the system
  /// ones.
  final int userExercises = 0,
  final int userWorkoutTemplates = 0,

  /// Looking a session up by id (Swift's Firebase Test).
  final bool isFetchingSession = false,

  /// What the last lookup found.
  final WorkoutSessionModel? fetchedSession,

  /// Why the last lookup failed; `notFound` when nothing has that id.
  final String? fetchError,
}) extends Equatable {
  /// [fetchError] when the lookup found nothing.
  static const notFound = 'notFound';

  @override
  List<Object?> get props => [
    simulatePremium,
    userExercises,
    userWorkoutTemplates,
    isFetchingSession,
    fetchedSession,
    fetchError,
  ];
}

/// The developer tools (Swift `DevSettingsPresenter`), in development and
/// staging builds only: Simulate Premium, signing out, the signed-in
/// user's details, the library's size and a session lookup.
///
/// The A/B test overrides go through the app's `AbTestsCubit`. Swift's
/// seeding resets have nothing to reset: Flutter reads the prebuilt
/// catalogue from the app, never from the device.
class DevSettingsCubit extends Cubit<DevSettingsState> {
  new({
    required this._auth,
    required this._purchases,
    required this._sessions,
    required this._library,
    required this._analytics,
    required this._uid,
  }) : super(
         DevSettingsState(
           simulatePremium: switch (_purchases) {
             final FakePurchasesRepository fake => fake.premium,
             _ => null,
           },
         ),
       );

  final AuthRepository _auth;
  final PurchasesRepository _purchases;
  final WorkoutSessionRepository _sessions;
  final TrainingLibraryRepository _library;
  final AnalyticsRepository _analytics;
  final String _uid;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// `DevSettingsView_Appear`, and the library's counts from now on.
  void appeared() {
    _analytics.appear('DevSettingsView');
    _subscriptions.addAll([
      _library
          .watchUserExercises(_uid)
          .listen(
            (list) => emit(_copy(userExercises: list.length)),
            onError: (_) {},
          ),
      _library
          .watchUserWorkoutTemplates(_uid)
          .listen(
            (list) => emit(_copy(userWorkoutTemplates: list.length)),
            onError: (_) {},
          ),
    ]);
  }

  /// `DevSettingsView_Disappear`.
  void disappeared() => _analytics.disappear('DevSettingsView');

  /// Treats this device as a subscriber, or not (`PremiumOverride`).
  void simulatePremiumChanged({required bool value}) {
    final purchases = _purchases;
    if (purchases is! FakePurchasesRepository) return;
    purchases.premium = value;
    emit(_copy(simulatePremium: value));
  }

  /// Reads `users/{uid}/workout_sessions/{id}` (`fetchSessionFromFirebase`),
  /// forgetting the last result first.
  Future<void> fetchSession(String id) async {
    emit(_copy(isFetchingSession: true, lookup: (session: null, error: null)));
    try {
      final session = await _sessions.session(_uid, id.trim());
      emit(
        _copy(
          isFetchingSession: false,
          lookup: (
            session: session,
            error: session == null ? DevSettingsState.notFound : null,
          ),
        ),
      );
    } on Object catch (error) {
      _analytics.severe('DevSettingsView_FetchSession_Fail', error);
      emit(
        _copy(
          isFetchingSession: false,
          lookup: (session: null, error: '$error'),
        ),
      );
    }
  }

  /// Signs out (`onForceFreshAnonUser`); the router then leaves for
  /// sign-in, where a fresh anonymous account can start onboarding. Whether
  /// it signed out.
  Future<bool> signOutPressed() async {
    _analytics.analytic('DevSettingsView_ForceSignOut_Start');
    try {
      await _auth.signOut();
      _analytics.analytic('DevSettingsView_ForceSignOut_Success');
      return true;
    } on Object catch (error) {
      _analytics.severe('DevSettingsView_ForceSignOut_Fail', error);
      return false;
    }
  }

  /// The state with these changes; the lookup's result is kept unless
  /// [lookup] replaces it.
  DevSettingsState _copy({
    bool? simulatePremium,
    int? userExercises,
    int? userWorkoutTemplates,
    bool? isFetchingSession,
    ({WorkoutSessionModel? session, String? error})? lookup,
  }) => DevSettingsState(
    simulatePremium: simulatePremium ?? state.simulatePremium,
    userExercises: userExercises ?? state.userExercises,
    userWorkoutTemplates: userWorkoutTemplates ?? state.userWorkoutTemplates,
    isFetchingSession: isFetchingSession ?? state.isFetchingSession,
    fetchedSession: lookup == null ? state.fetchedSession : lookup.session,
    fetchError: lookup == null ? state.fetchError : lookup.error,
  );

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await super.close();
  }
}

/// The signed-in account's details, by name (`UserAuthInfo.eventParameters`,
/// sorted as Swift's `asAlphabeticalArray`); empty when nobody is signed in.
List<(String, String)> devAuthParameters(AuthUser? user) => user == null
    ? const []
    : _sorted({
        'uauth_display_name': user.displayName,
        'uauth_email': user.email,
        'uauth_is_anonymous': user.isAnonymous,
        'uauth_providers': user.providers.map((p) => p.name).join(', '),
        'uauth_user_id': user.uid,
      });

/// The profile as stored, field by field (`UserModel.eventParameters`);
/// empty without one.
List<(String, String)> devUserParameters(UserModel? profile) =>
    profile == null ? const [] : _sorted(profile.toFirestore());

List<(String, String)> _sorted(Map<String, Object?> values) => [
  for (final key in values.keys.toList()..sort())
    if (values[key] case final value?) (key, '$value'),
];
