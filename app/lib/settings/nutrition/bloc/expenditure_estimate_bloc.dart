import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:equatable/equatable.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';

part 'expenditure_estimate_event.dart';
part 'expenditure_estimate_state.dart';

/// Today's expenditure as the Expenditure screen shows it above its
/// controls (Swift `currentExpenditure`), from everything the engine reads,
/// each followed live, so a changed setting moves the figure at once.
class ExpenditureEstimateBloc
    extends Bloc<ExpenditureEstimateEvent, ExpenditureEstimateState> {
  new({
    required this._checkInRepository,
    required this._nutritionRepository,
    required this._bodyRepository,
    required this._userRepository,
    required this._uid,
    DateTime Function() now = DateTime.now,
  }) : super(ExpenditureEstimateState(now: now())) {
    on<ExpenditureEstimateSubscriptionRequested>(_onSubscriptionRequested);
  }

  final CheckInRepository _checkInRepository;
  final NutritionRepository _nutritionRepository;
  final BodyRepository _bodyRepository;
  final UserRepository _userRepository;
  final String _uid;

  // Every stream but the settings is optional to the estimate: a failure
  // leaves the state as it was rather than hiding the figure.
  Future<void> _onSubscriptionRequested(
    ExpenditureEstimateSubscriptionRequested event,
    Emitter<ExpenditureEstimateState> emit,
  ) {
    ExpenditureEstimateState kept(Object _, StackTrace _) => state;
    return Future.wait([
      emit.forEach(
        _checkInRepository.watchStrategySettings(_uid),
        onData: (settings) => state.copyWith(settings: () => settings),
        onError: kept,
      ),
      emit.forEach(
        _userRepository.watchUser(_uid),
        onData: (user) => state.copyWith(user: () => user),
        onError: kept,
      ),
      emit.forEach(
        _nutritionRepository.watchMeals(_uid),
        onData: (meals) => state.copyWith(meals: meals),
        onError: kept,
      ),
      emit.forEach(
        _bodyRepository.watchMeasurements(_uid),
        onData: (measurements) => state.copyWith(measurements: measurements),
        onError: kept,
      ),
      emit.forEach(
        _bodyRepository.watchSteps(_uid),
        onData: (steps) => state.copyWith(steps: steps),
        onError: kept,
      ),
      emit.forEach(
        _checkInRepository.watchDayAnnotations(_uid),
        onData: (annotations) => state.copyWith(annotations: annotations),
        onError: kept,
      ),
      emit.forEach(
        _checkInRepository.watchLoggingBreak(_uid),
        onData: (loggingBreak) =>
            state.copyWith(loggingBreak: () => loggingBreak),
        onError: kept,
      ),
    ]);
  }
}
