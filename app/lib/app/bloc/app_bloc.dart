import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'app_event.dart';
part 'app_state.dart';

/// Whether anyone is signed in, following [AuthRepository.user].
class AppBloc extends Bloc<AppEvent, AppState> {
  new({required this._authRepository})
    : super(AppState.from(_authRepository.currentUser)) {
    on<AppUserSubscriptionRequested>(_onUserSubscriptionRequested);
    on<AppSignOutPressed>(_onSignOutPressed);
  }

  final AuthRepository _authRepository;

  Future<void> _onUserSubscriptionRequested(
    AppUserSubscriptionRequested event,
    Emitter<AppState> emit,
  ) => emit.onEach(
    _authRepository.user,
    onData: (user) => emit(AppState.from(user)),
    onError: addError,
  );

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
