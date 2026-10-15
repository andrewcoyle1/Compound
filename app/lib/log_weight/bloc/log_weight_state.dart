part of 'log_weight_bloc.dart';

/// Where the screen has got to.
enum LogWeightStatus {
  /// Reading the latest weigh-in and the profile.
  loading,

  /// Ready to save.
  ready,

  /// Saving.
  saving,

  /// Saved: the screen closes.
  saved,

  /// The save failed; the user can try again.
  failure,
}

/// The weigh-in being entered (Swift `LogWeightPresenter`): its day, and the
/// weight on both units' wheels, kept in step so switching unit shows the
/// same weight.
final class const LogWeightState({
  /// The day, at the time of day the screen opened.
  required final DateTime date,
  final LogWeightStatus status = LogWeightStatus.loading,

  /// The unit shown, and saved as the profile's preference.
  final WeightUnitPreference unit = WeightUnitPreference.kilograms,
  final int kilograms = 70,
  final int kilogramsTenths = 0,
  final int pounds = 154,
  final int poundsTenths = 0,
}) extends Equatable {
  /// The weight to save, in kilograms, read from the wheels of [unit]
  /// (Swift `weightKg`).
  double get weightKg => switch (unit) {
    WeightUnitPreference.kilograms => DecimalWheelValue.combine(
      whole: kilograms,
      tenths: kilogramsTenths,
    ),
    WeightUnitPreference.pounds =>
      DecimalWheelValue.combine(whole: pounds, tenths: poundsTenths) /
          AppFormat.poundsPerKilogram,
  };

  /// Whether the user can change anything or save.
  bool get isEditable =>
      status == LogWeightStatus.ready || status == LogWeightStatus.failure;

  LogWeightState copyWith({
    DateTime? date,
    LogWeightStatus? status,
    WeightUnitPreference? unit,
    int? kilograms,
    int? kilogramsTenths,
    int? pounds,
    int? poundsTenths,
  }) => LogWeightState(
    date: date ?? this.date,
    status: status ?? this.status,
    unit: unit ?? this.unit,
    kilograms: kilograms ?? this.kilograms,
    kilogramsTenths: kilogramsTenths ?? this.kilogramsTenths,
    pounds: pounds ?? this.pounds,
    poundsTenths: poundsTenths ?? this.poundsTenths,
  );

  /// The wheels set to [weightKg] in both units, each whole number kept
  /// inside its wheel's span.
  LogWeightState withKilograms(double weightKg) {
    final kg = _onWheel(weightKg, WeightWheelRange.kilograms);
    final lb = _onWheel(
      weightKg * AppFormat.poundsPerKilogram,
      WeightWheelRange.pounds,
    );
    return copyWith(
      kilograms: kg.whole,
      kilogramsTenths: kg.tenths,
      pounds: lb.whole,
      poundsTenths: lb.tenths,
    );
  }

  /// The wheels set to [pounds] in pounds, and its conversion in kilograms.
  LogWeightState withPounds(double pounds) {
    final lb = _onWheel(pounds, WeightWheelRange.pounds);
    final kg = _onWheel(
      pounds / AppFormat.poundsPerKilogram,
      WeightWheelRange.kilograms,
    );
    return copyWith(
      kilograms: kg.whole,
      kilogramsTenths: kg.tenths,
      pounds: lb.whole,
      poundsTenths: lb.tenths,
    );
  }

  /// The wheels with [whole] on the whole-number wheel of [unit].
  LogWeightState withWhole(int whole) => switch (unit) {
    WeightUnitPreference.kilograms => withKilograms(
      DecimalWheelValue.combine(whole: whole, tenths: kilogramsTenths),
    ),
    WeightUnitPreference.pounds => withPounds(
      DecimalWheelValue.combine(whole: whole, tenths: poundsTenths),
    ),
  };

  /// The wheels with [tenths] on the tenths wheel of [unit].
  LogWeightState withTenths(int tenths) => switch (unit) {
    WeightUnitPreference.kilograms => withKilograms(
      DecimalWheelValue.combine(whole: kilograms, tenths: tenths),
    ),
    WeightUnitPreference.pounds => withPounds(
      DecimalWheelValue.combine(whole: pounds, tenths: tenths),
    ),
  };

  @override
  List<Object> get props => [
    date,
    status,
    unit,
    kilograms,
    kilogramsTenths,
    pounds,
    poundsTenths,
  ];
}

/// [value] split for the wheels, its whole part kept inside [range]. Swift's
/// wheel shows no row for a value outside it but still saves it; here what is
/// shown is what is saved.
({int whole, int tenths}) _onWheel(double value, ({int min, int max}) range) {
  final (:whole, :tenths) = DecimalWheelValue.split(value);
  return (whole: whole.clamp(range.min, range.max), tenths: tenths);
}
