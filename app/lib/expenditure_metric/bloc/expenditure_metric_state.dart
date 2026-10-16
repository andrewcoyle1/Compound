part of 'expenditure_metric_bloc.dart';

/// Where the screen's data has got to.
enum ExpenditureMetricStatus { loading, loaded, failure }

/// The engine's history and the meals, as last read, and what each screen
/// draws from them.
final class const ExpenditureMetricState({
  required final ExpenditureMetric metric,

  /// Today, at midnight: the charts end on it.
  required final DateTime today,
  final MetricRange range = MetricRange.month,

  /// One estimate per day; null until the data arrives.
  final List<ExpenditureEstimate>? history,

  /// The profile's formula expenditure.
  final double formulaKcal = 0,
  final List<MealLogModel> meals = const [],
  final bool failed = false,
}) extends Equatable {
  ExpenditureMetricStatus get status => failed
      ? ExpenditureMetricStatus.failure
      : history == null
      ? ExpenditureMetricStatus.loading
      : ExpenditureMetricStatus.loaded;

  String get _todayKey => localDayKey(today);

  /// Today's estimate, for the summary above the list; null with no
  /// history.
  ExpenditureEstimate? get currentEstimate => history?.lastOrNull;

  /// Expenditure's points, oldest first.
  List<MetricPoint> get expenditure =>
      expenditurePoints(history ?? const [], formulaKcal, _todayKey);

  /// Energy Balance's expenditure line, every day, and its days with
  /// calories logged, oldest first.
  ({List<MetricPoint> expenditure, List<EnergyBalanceDay> days}) get balance =>
      energyBalance(
        history: history ?? const [],
        formulaKcal: formulaKcal,
        meals: meals,
        today: _todayKey,
      );

  ExpenditureMetricState copyWith({
    MetricRange? range,
    List<ExpenditureEstimate>? history,
    double? formulaKcal,
    List<MealLogModel>? meals,
    bool? failed,
  }) => ExpenditureMetricState(
    metric: metric,
    today: today,
    range: range ?? this.range,
    history: history ?? this.history,
    formulaKcal: formulaKcal ?? this.formulaKcal,
    meals: meals ?? this.meals,
    failed: failed ?? this.failed,
  );

  @override
  List<Object?> get props => [
    metric,
    today,
    range,
    history,
    formulaKcal,
    meals,
    failed,
  ];
}
