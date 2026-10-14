import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';

enum SignInStatus { idle, inProgress, failure }

/// Runs one sign-in at a time. Success needs no state of its own: the
/// AppBloc sees the new user and the router leaves this page.
class SignInCubit extends Cubit<SignInStatus> {
  new({required this._authRepository}) : super(SignInStatus.idle);

  final AuthRepository _authRepository;

  Future<void> signInWithGoogle() => _signIn(_authRepository.signInWithGoogle);

  Future<void> signInWithApple() => _signIn(_authRepository.signInWithApple);

  Future<void> signInAnonymously() =>
      _signIn(_authRepository.signInAnonymously);

  Future<void> _signIn(Future<void> Function() signIn) async {
    emit(SignInStatus.inProgress);
    try {
      await signIn();
      emit(SignInStatus.idle);
    } on SignInCancelled {
      emit(SignInStatus.idle);
    } on AuthFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(SignInStatus.failure);
    }
  }
}
