import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

part 'workout_session_detail_event.dart';
part 'workout_session_detail_state.dart';

/// One of the signed-in user's workouts, with the units their profile shows
/// totals and distances in.
class WorkoutSessionDetailBloc
    extends Bloc<WorkoutSessionDetailEvent, WorkoutSessionDetailState> {
  new({
    required this._sessionRepository,
    required this._userRepository,
    required this._uid,
    required this._sessionId,
    this._session,
  }) : super(const WorkoutSessionDetailLoading()) {
    on<WorkoutSessionDetailRequested>(_onRequested);
  }

  final WorkoutSessionRepository _sessionRepository;
  final UserRepository _userRepository;
  final String _uid;
  final String _sessionId;

  /// The workout, when the caller has it: a summary shows the workout just
  /// finished without waiting for its save.
  final WorkoutSessionModel? _session;

  Future<void> _onRequested(
    WorkoutSessionDetailRequested event,
    Emitter<WorkoutSessionDetailState> emit,
  ) async {
    emit(const WorkoutSessionDetailLoading());
    final WorkoutSessionModel? session;
    try {
      session = _session ?? await _sessionRepository.session(_uid, _sessionId);
    } on Object {
      emit(const WorkoutSessionDetailFailure());
      return;
    }
    if (session == null) {
      emit(const WorkoutSessionDetailNotFound());
      return;
    }
    // The units are a nicety: without the profile, kilograms and kilometres.
    UserModel? user;
    try {
      user = await _userRepository.watchUser(_uid).first;
    } on Object {
      user = null;
    }
    emit(
      WorkoutSessionDetailLoaded(
        session: session,
        weightUnit: user?.submittedWeightUnitPreference,
        distanceUnit: user?.submittedDistanceUnitPreference,
      ),
    );
  }
}
