import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

part 'workout_session_detail_event.dart';
part 'workout_session_detail_state.dart';

/// A workout, the signed-in user's or someone else's, with the units the
/// user's profile shows totals and distances in.
class WorkoutSessionDetailBloc
    extends Bloc<WorkoutSessionDetailEvent, WorkoutSessionDetailState> {
  new({
    required this._sessionRepository,
    required this._userRepository,
    required this._uid,
    required this._sessionId,
    this._socialRepository,
    this._authorId,
    this._session,
  }) : super(const WorkoutSessionDetailLoading()) {
    on<WorkoutSessionDetailRequested>(_onRequested);
  }

  final WorkoutSessionRepository _sessionRepository;
  final UserRepository _userRepository;
  final String _uid;
  final String _sessionId;

  /// Reads someone else's workout, by [_authorId].
  final SocialRepository? _socialRepository;

  /// Who did it, when it may be someone else's: a link to their workout
  /// carries no copy of it.
  final String? _authorId;

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
      final authorId = _authorId ?? _uid;
      session =
          _session ??
          (authorId == _uid
              ? await _sessionRepository.session(_uid, _sessionId)
              : await _socialRepository?.sessionById(
                  _sessionId,
                  authorId: authorId,
                ));
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
