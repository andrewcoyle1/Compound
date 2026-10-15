import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

part 'app_event.dart';
part 'app_state.dart';

/// Whether anyone is signed in, following [AuthRepository.user]; who
/// analytics attributes events to; and the signed-in user's profile, which
/// decides between onboarding and the tabs.
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
    this._now = DateTime.now,
  }) : super(AppState.from(_authRepository.currentUser)) {
    on<AppUserSubscriptionRequested>(_onUserSubscriptionRequested);
    on<AppSignOutPressed>(_onSignOutPressed);
    on<AppProfileRetryRequested>(_onProfileRetryRequested);
    on<_AppProfileChanged>(_onProfileChanged);
    on<_AppProfileFailed>(_onProfileFailed);
  }

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final AnalyticsRepository _analyticsRepository;
  final DateTime Function() _now;

  StreamSubscription<UserModel?>? _profileSubscription;

  /// The uid whose missing profile is being checked or written, so a second
  /// empty read meanwhile does not write it twice.
  String? _creatingFor;

  Future<void> _onUserSubscriptionRequested(
    AppUserSubscriptionRequested event,
    Emitter<AppState> emit,
  ) => emit.onEach(
    _authRepository.user,
    onData: (user) {
      _logUser(user);
      final current = state;
      // The same account again (a token refresh, or linking an anonymous
      // account to Apple or Google): keep the profile already read, so the
      // router doesn't send anyone back through the launch screen.
      if (user != null &&
          current is AppAuthenticated &&
          current.user.uid == user.uid &&
          _profileSubscription != null) {
        emit(
          AppAuthenticated(
            user,
            profile: current.profile,
            profileStatus: current.profileStatus,
          ),
        );
        return;
      }
      emit(AppState.from(user));
      _watchProfile(user);
    },
    onError: addError,
  );

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
        AppAuthenticated(
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
          displayName: user.displayName,
          creationDate: now,
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
    emit(AppAuthenticated(user, profileStatus: AppProfileStatus.failure));
  }

  void _onProfileRetryRequested(
    AppProfileRetryRequested event,
    Emitter<AppState> emit,
  ) {
    final state = this.state;
    if (state is! AppAuthenticated) return;
    emit(AppAuthenticated(state.user));
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
    await super.close();
  }
}
