import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart' show AppFormat, AppWeightUnit;
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound/nutrition/logic/meal_day.dart' show startOfDay;
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/undo/pending_deletes.dart';
import 'package:compound/weight_metric/models/weight_metric.dart';
import 'package:compound_models/compound_models.dart'
    show BodyMeasurementEntryKeys;
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

part 'weight_metric_event.dart';
part 'weight_metric_state.dart';

/// The Scale Weight or Weight Trend screen: the user's weigh-ins from
/// [BodyRepository], followed live so a weigh-in imported elsewhere
/// appears while the screen is open, and the weight unit from their
/// profile. A weigh-in deleted from All Recorded Data loses its weight and
/// nothing else logged that day.
class WeightMetricBloc extends Bloc<WeightMetricEvent, WeightMetricState> {
  new({
    required this._bodyRepository,
    required this._userRepository,
    required this._analyticsRepository,
    required this._uid,
    required WeightMetric metric,
    DateTime Function() now = DateTime.now,
    this._pendingDeletes,
  }) : super(WeightMetricState(metric: metric, today: startOfDay(now()))) {
    on<WeightMetricSubscriptionRequested>(_onSubscriptionRequested);
    on<WeightMetricRangeSelected>(_onRangeSelected);
  }

  final BodyRepository _bodyRepository;
  final UserRepository _userRepository;
  final AnalyticsRepository _analyticsRepository;
  final String _uid;

  /// Weigh-ins waiting on an Undo, left out of the list and the trend.
  final PendingDeletes? _pendingDeletes;

  String get _screen => state.metric.analyticsName;

  Future<void> _onSubscriptionRequested(
    WeightMetricSubscriptionRequested event,
    Emitter<WeightMetricState> emit,
  ) {
    _analyticsRepository.appear(_screen);
    List<BodyMeasurementEntry>? stored;
    var hidden = const <String>{};
    WeightMetricState shown() {
      final weighIns = weighInsOf(stored!)
          .hide(hidden, (entry) => PendingKeys.weighIn(entry.id));
      return state.copyWith(
        weighIns: weighIns,
        trendKg: trendOf(weighIns),
        failed: false,
      );
    }

    return Future.wait([
      emit.forEach(
        _bodyRepository.watchMeasurements(_uid),
        onData: (measurements) {
          stored = measurements;
          return shown();
        },
        onError: (_, _) => state.copyWith(failed: true),
      ),
      if (_pendingDeletes case final pending?)
        emit.forEach(
          pending.watch(),
          onData: (keys) {
            hidden = keys;
            return stored == null ? state : shown();
          },
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
  }

  void _onRangeSelected(
    WeightMetricRangeSelected event,
    Emitter<WeightMetricState> emit,
  ) => emit(state.copyWith(range: event.range));

  /// Clears weigh-in [entryId]'s weight with a delete, not Swift's merge
  /// (which loses the clear), logging `<screen>_DeleteEntry_*`, once its
  /// Undo has gone. A failure is rethrown for the snack bar to report.
  Future<void> deleteEntry(String entryId) async {
    final screen = _screen;
    _analyticsRepository.analytic('${screen}_DeleteEntry_Start');
    try {
      await _bodyRepository.clearMeasurementFields(_uid, entryId, {
        BodyMeasurementEntryKeys.weightKg,
      });
      _analyticsRepository.analytic('${screen}_DeleteEntry_Success');
    } on Object catch (error) {
      _analyticsRepository.severe('${screen}_DeleteEntry_Fail', error);
      rethrow;
    }
  }

  @override
  Future<void> close() {
    if (!isClosed) _analyticsRepository.disappear(_screen);
    return super.close();
  }
}
