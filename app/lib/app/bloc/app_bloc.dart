import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:equatable/equatable.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:user_repository/user_repository.dart';

part 'app_event.dart';
part 'app_state.dart';

/// Whether anyone is signed in, following [AuthRepository.user]; who
/// analytics attributes events to; and the signed-in user's profile, which
/// decides between onboarding and the tabs.
///
/// The store account follows the signed-in user too: `logIn` with the
/// Firebase uid on sign-in and `logOut` on sign-out, as Swift's
/// `CoreInteractor.logIn` and `signOut` do, and whether the user is premium
/// is part of [AppAuthenticated].
///
/// A new account's profile is written here, as `UserManager.signIn` does
/// for a new user (`UserManager.swift:56-60`): only once the server says
/// there is no `users/{uid}`, never on a cache miss, because writing a new
/// profile over an existing one would reset its onboarding.
class AppBloc extends Bloc<AppEvent, AppState> {
  new({
    required this._authRepository,
    required this._userRepository,
    this._analyticsRepository = const AnalyticsRepository(),
    this._purchasesRepository,
    this._now = DateTime.now,
    this._appVersion,
  }) : _launchUid = _authRepository.currentUser?.uid,
       super(AppState.from(_authRepository.currentUser)) {
    on<AppUserSubscriptionRequested>(_onUserSubscriptionRequested);
    on<AppSignOutPressed>(_onSignOutPressed);
    on<AppProfileRetryRequested>(_onProfileRetryRequested);
    on<_AppProfileChanged>(_onProfileChanged);
    on<_AppProfileFailed>(_onProfileFailed);
    on<_AppPurchasesChanged>(_onPurchasesChanged);
  }

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final AnalyticsRepository _analyticsRepository;

  /// Subscriptions. Only `App` passes it; left out (tests that never reach
  /// a subscription) there is no store and nobody is sent to Subscription.
  final PurchasesRepository? _purchasesRepository;
  final DateTime Function() _now;

  /// The app's version (`CFBundleShortVersionString`, Android's
  /// `versionName`), stamped on a new profile as `creation_version`.
  final String? _appVersion;

  /// Who was signed in when the app started, until they sign out: anyone
  /// else signed in during this run (Swift's sign-in screen).
  String? _launchUid;

  /// What the store last said, as the premium gate reads it (optimistic
  /// until it has answered for the signed-in user).
  bool _isPremium = true;

  StreamSubscription<UserModel?>? _profileSubscription;
  StreamSubscription<PurchasesState>? _purchasesSubscription;

  /// The uid whose missing profile is being checked or written, so a second
  /// empty read meanwhile does not write it twice.
  String? _creatingFor;

  /// [user], signed in, with what is known of their profile and premium.
  AppAuthenticated _authenticated(
    AuthUser user, {
    UserModel? profile,
    AppProfileStatus profileStatus = AppProfileStatus.loading,
  }) => AppAuthenticated(
    user,
    profile: profile,
    profileStatus: profileStatus,
    isPremium: _isPremium,
    signedInThisRun: user.uid != _launchUid,
  );

  Future<void> _onUserSubscriptionRequested(
    AppUserSubscriptionRequested event,
    Emitter<AppState> emit,
  ) {
    final purchases = _purchasesRepository;
    if (purchases != null) {
      _purchasesSubscription ??= purchases.states.listen(
        (state) => add(_AppPurchasesChanged(state)),
      );
    }
    return emit.onEach(
      _authRepository.user,
      onData: (user) {
        _logUser(user);
        final current = state;
        // The same account again (a token refresh, or linking an anonymous
        // account to Apple or Google): keep the profile already read, so
        // the router doesn't send anyone back through the launch screen.
        if (user != null &&
            current is AppAuthenticated &&
            current.user.uid == user.uid &&
            _profileSubscription != null) {
          emit(
            _authenticated(
              user,
              profile: current.profile,
              profileStatus: current.profileStatus,
            ),
          );
          return;
        }
        if (user == null) _launchUid = null;
        emit(user == null ? const AppUnauthenticated() : _authenticated(user));
        _watchProfile(user);
        unawaited(
          _followStoreAccount(user, wasSignedIn: current is AppAuthenticated),
        );
      },
      onError: addError,
    );
  }

  /// Identifies the store account as [user]'s Firebase uid, with their
  /// email and the Mixpanel and Firebase Analytics ids as Swift's `logIn`
  /// sends them, or forgets it once nobody is signed in. A failure (offline,
  /// most often) leaves the store unanswered, so the gate stays optimistic
  /// until the next sign-in.
  Future<void> _followStoreAccount(
    AuthUser? user, {
    required bool wasSignedIn,
  }) async {
    final purchases = _purchasesRepository;
    if (purchases == null) return;
    try {
      if (user != null) {
        final analytics = _analyticsRepository;
        await purchases.logIn(
          user.uid,
          email: user.email,
          mixpanelDistinctId: await analytics.mixpanelDistinctId(),
          firebaseAppInstanceId: await analytics.firebaseAppInstanceId(),
        );
      } else if (wasSignedIn) {
        await purchases.logOut();
      }
    } on Object catch (error, stackTrace) {
      if (!isClosed) addError(error, stackTrace);
    }
  }

  void _onPurchasesChanged(_AppPurchasesChanged event, Emitter<AppState> emit) {
    _isPremium = event.state.isPremiumWith();
    final state = this.state;
    if (state is! AppAuthenticated) return;
    emit(
      _authenticated(
        state.user,
        profile: state.profile,
        profileStatus: state.profileStatus,
      ),
    );
  }

  void _watchProfile(AuthUser? user) {
    unawaited(_profileSubscription?.cancel());
    _profileSubscription = null;
    if (user == null) return;
    _profileSubscription = _userRepository
        .watchUser(user.uid)
        .listen(
          (profile) => add(_AppProfileChanged(user, profile)),
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            add(_AppProfileFailed(user));
          },
        );
  }

  /// The signed-in user, if their uid is [uid].
  AuthUser? _current(String uid) => switch (state) {
    AppAuthenticated(:final user) when user.uid == uid => user,
    _ => null,
  };

  Future<void> _onProfileChanged(
    _AppProfileChanged event,
    Emitter<AppState> emit,
  ) async {
    final user = _current(event.user.uid);
    if (user == null) return;
    final profile = event.profile;
    if (profile != null) {
      emit(
        _authenticated(
          user,
          profile: profile,
          profileStatus: AppProfileStatus.ready,
        ),
      );
      return;
    }
    // A profile read before that has gone (deleted, or no longer decodes)
    // is never replaced: only a first read can find a new account.
    if ((state as AppAuthenticated).profileStatus != AppProfileStatus.loading) {
      _fail(user.uid, emit);
      return;
    }
    if (_creatingFor == user.uid) return;
    _creatingFor = user.uid;
    try {
      if (await _userRepository.userExists(user.uid)) {
        // There, but it doesn't decode: never write over it.
        _fail(user.uid, emit);
        return;
      }
      // The listener sees the new profile and emits it.
      final now = _now();
      await _userRepository.createUser(
        UserModel(
          userId: user.uid,
          email: user.email,
          isAnonymous: user.isAnonymous,
          // Swift writes `AuthProviderOption.rawValue`: "apple", "google".
          authProviders: [for (final provider in user.providers) provider.name],
          displayName: user.displayName,
          creationDate: now,
          creationVersion: _appVersion,
          lastSignInDate: now,
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      _fail(user.uid, emit);
    } finally {
      _creatingFor = null;
    }
  }

  void _onProfileFailed(_AppProfileFailed event, Emitter<AppState> emit) =>
      _fail(event.user.uid, emit);

  void _fail(String uid, Emitter<AppState> emit) {
    final user = _current(uid);
    if (user == null) return;
    emit(_authenticated(user, profileStatus: AppProfileStatus.failure));
  }

  void _onProfileRetryRequested(
    AppProfileRetryRequested event,
    Emitter<AppState> emit,
  ) {
    final state = this.state;
    if (state is! AppAuthenticated) return;
    emit(_authenticated(state.user));
    _watchProfile(state.user);
  }

  /// As SwiftfulAuthenticating's auth listener does, with the same event
  /// names. The name and email go only to identifyUser, not into event
  /// parameters or user properties.
  void _logUser(AuthUser? user) {
    if (user == null) {
      _analyticsRepository.trackEvent(
        const AnalyticsEvent('Auth_Listener_Empty', type: LogType.warning),
      );
      return;
    }
    final parameters = {
      'uauth_user_id': user.uid,
      'uauth_is_anonymous': user.isAnonymous,
    };
    _analyticsRepository
      ..identifyUser(
        userId: user.uid,
        name: user.displayName,
        email: user.email,
      )
      ..addUserProperties(parameters, isHighPriority: true)
      ..trackEvent(
        AnalyticsEvent(
          'Auth_Listener_Success',
          parameters: parameters,
          type: LogType.info,
        ),
      );
  }

  Future<void> _onSignOutPressed(
    AppSignOutPressed event,
    Emitter<AppState> emit,
  ) async {
    try {
      await _authRepository.signOut();
    } on AuthFailure catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _profileSubscription?.cancel();
    await _purchasesSubscription?.cancel();
    await super.close();
  }
}
