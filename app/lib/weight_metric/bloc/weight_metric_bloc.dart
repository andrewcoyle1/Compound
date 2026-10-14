import 'package:app_ui/app_ui.dart' show AppFormat, AppWeightUnit;
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound/nutrition/logic/meal_day.dart' show startOfDay;
import 'package:compound/weight_metric/models/weight_metric.dart';
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

part 'weight_metric_event.dart';
part 'weight_metric_state.dart';

/// The Scale Weight or Weight Trend screen: the user's weigh-ins from
/// [BodyRepository], followed live so a weigh-in imported elsewhere
/// appears while the screen is open, and the weight unit from their
/// profile.
class WeightMetricBloc extends Bloc<WeightMetricEvent, WeightMetricState> {
  new({
    required this._bodyRepository,
    required this._userRepository,
    required this._uid,
    required WeightMetric metric,
    DateTime Function() now = DateTime.now,
  }) : super(WeightMetricState(metric: metric, today: startOfDay(now()))) {
    on<WeightMetricSubscriptionRequested>(_onSubscriptionRequested);
    on<WeightMetricRangeSelected>(_onRangeSelected);
  }

  final BodyRepository _bodyRepository;
  final UserRepository _userRepository;
  final String _uid;

  Future<void> _onSubscriptionRequested(
    WeightMetricSubscriptionRequested event,
    Emitter<WeightMetricState> emit,
  ) => Future.wait([
    emit.forEach(
      _bodyRepository.watchMeasurements(_uid),
      onData: (measurements) {
        final weighIns = weighInsOf(measurements);
        return state.copyWith(
          weighIns: weighIns,
          trendKg: trendOf(weighIns),
          failed: false,
        );
      },
      onError: (_, _) => state.copyWith(failed: true),
    ),
    // The unit is a nicety: without the profile, kilograms.
    emit.forEach(
      _userRepository.watchUser(_uid),
      onData: (user) => state.copyWith(
        weightUnitPreference: () => user?.submittedWeightUnitPreference,
      ),
      onError: (_, _) => state,
    ),
  ]);

  void _onRangeSelected(
    WeightMetricRangeSelected event,
    Emitter<WeightMetricState> emit,
  ) => emit(state.copyWith(range: event.range));
}
