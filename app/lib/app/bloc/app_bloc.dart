import 'package:analytics_repository/analytics_repository.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'app_event.dart';
part 'app_state.dart';

/// Whether anyone is signed in, following [AuthRepository.user], and who
/// analytics attributes events to.
class AppBloc extends Bloc<AppEvent, AppState> {
  new({
    required this._authRepository,
    this._analyticsRepository = const AnalyticsRepository(),
  }) : super(AppState.from(_authRepository.currentUser)) {
    on<AppUserSubscriptionRequested>(_onUserSubscriptionRequested);
    on<AppSignOutPressed>(_onSignOutPressed);
  }

  final AuthRepository _authRepository;
  final AnalyticsRepository _analyticsRepository;

  Future<void> _onUserSubscriptionRequested(
    AppUserSubscriptionRequested event,
    Emitter<AppState> emit,
  ) => emit.onEach(
    _authRepository.user,
    onData: (user) {
      _logUser(user);
      emit(AppState.from(user));
    },
    onError: addError,
  );

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
}
