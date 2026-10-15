import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/expenditure/expenditure.dart';
import 'package:compound/expenditure_metric/models/expenditure_metric.dart';
import 'package:compound/metric_detail/models/metric_readings.dart';
import 'package:compound/nutrition/logic/meal_day.dart' show startOfDay;
import 'package:equatable/equatable.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';

part 'expenditure_metric_event.dart';
part 'expenditure_metric_state.dart';

/// Expenditure or Energy Balance (Swift `ExpenditureDetailPresenter`,
/// `EnergyBalancePresenter`): the engine's history worked out from the
/// user's logs, followed live so a meal or weigh-in logged elsewhere moves
/// the chart while the screen is open.
class ExpenditureMetricBloc
    extends Bloc<ExpenditureMetricEvent, ExpenditureMetricState> {
  new({
    required this._users,
    required this._nutrition,
    required this._body,
    required this._checkIns,
    required this._analytics,
    required this._uid,
    required ExpenditureMetric metric,
    this._now = DateTime.now,
  }) : super(
         ExpenditureMetricState(metric: metric, today: startOfDay(_now())),
       ) {
    on<ExpenditureMetricSubscriptionRequested>(_onSubscriptionRequested);
    on<ExpenditureMetricRangeSelected>(
      (event, emit) => emit(state.copyWith(range: event.range)),
    );
  }

  final UserRepository _users;
  final NutritionRepository _nutrition;
  final BodyRepository _body;
  final CheckInRepository _checkIns;
  final AnalyticsRepository _analytics;
  final String _uid;
  final DateTime Function() _now;

  Future<void> _onSubscriptionRequested(
    ExpenditureMetricSubscriptionRequested event,
    Emitter<ExpenditureMetricState> emit,
  ) {
    _analytics.trackScreenView(
      AnalyticsEvent('${state.metric.analyticsName}_Appear'),
    );
    return emit.forEach(
      watchExpenditure(
        uid: _uid,
        users: _users,
        nutrition: _nutrition,
        body: _body,
        checkIns: _checkIns,
      ),
      onData: (snapshot) {
        final inputs = snapshot.inputs(_now());
        return state.copyWith(
          history: inputs.history,
          formulaKcal: inputs.priorKcal,
          meals: snapshot.meals,
          failed: false,
        );
      },
      onError: (error, _) {
        // Swift logs only Energy Balance's failed read.
        if (state.metric == ExpenditureMetric.energyBalance) {
          _analytics.trackEvent(
            AnalyticsEvent(
              'EnergyBalanceView_Load_Fail',
              parameters: {'error_description': '$error'},
              type: LogType.warning,
            ),
          );
        }
        return state.copyWith(failed: true);
      },
    );
  }

  @override
  Future<void> close() {
    _analytics.trackEvent(
      AnalyticsEvent('${state.metric.analyticsName}_Disappear'),
    );
    return super.close();
  }
}
