part of 'expenditure_estimate_bloc.dart';

/// The engine's inputs as last read.
final class ExpenditureEstimateState extends Equatable {
  const new({
    required this.now,
    this.settings,
    this.user,
    this.meals = const [],
    this.measurements = const [],
    this.steps = const [],
    this.annotations = const [],
    this.loggingBreak,
  });

  /// The moment the estimate is for.
  final DateTime now;

  /// The strategy settings; null until read.
  final NutritionStrategySettings? settings;
  final UserModel? user;
  final List<MealLogModel> meals;
  final List<BodyMeasurementEntry> measurements;
  final List<StepsModel> steps;
  final List<NutritionDayAnnotation> annotations;
  final LoggingBreak? loggingBreak;

  /// Today's estimate, or null until the settings are read.
  maths.ExpenditureEstimate? get estimate {
    final settings = this.settings;
    if (settings == null) return null;
    return ExpenditureInputs(
      now: now,
      settings: settings,
      user: user,
      meals: meals,
      measurements: measurements,
      steps: steps,
      annotations: annotations,
      loggingBreak: loggingBreak,
    ).current;
  }

  ExpenditureEstimateState copyWith({
    NutritionStrategySettings? Function()? settings,
    UserModel? Function()? user,
    List<MealLogModel>? meals,
    List<BodyMeasurementEntry>? measurements,
    List<StepsModel>? steps,
    List<NutritionDayAnnotation>? annotations,
    LoggingBreak? Function()? loggingBreak,
  }) => ExpenditureEstimateState(
    now: now,
    settings: settings == null ? this.settings : settings(),
    user: user == null ? this.user : user(),
    meals: meals ?? this.meals,
    measurements: measurements ?? this.measurements,
    steps: steps ?? this.steps,
    annotations: annotations ?? this.annotations,
    loggingBreak: loggingBreak == null ? this.loggingBreak : loggingBreak(),
  );

  @override
  List<Object?> get props => [
    now,
    settings,
    user,
    meals,
    measurements,
    steps,
    annotations,
    loggingBreak,
  ];
}
