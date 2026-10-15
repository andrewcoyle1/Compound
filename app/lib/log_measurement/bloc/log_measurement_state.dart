part of 'log_measurement_bloc.dart';

/// Where the screen has got to.
enum LogMeasurementStatus {
  /// Reading the latest reading and the profile.
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

/// The reading being entered (Swift `LogMeasurementPresenter`): its day,
/// and the circumference on both units' wheels, kept in step so switching
/// unit shows the same length.
final class const LogMeasurementState({
  /// Which circumference.
  required final BodyMeasurementKind kind,

  /// The day, at the time of day the screen opened.
  required final DateTime date,

  /// The whole-number wheels: centimetres and inches.
  required final int centimetres,
  required final int inches,

  /// The tenths wheels.
  final int centimetresTenths = 0,
  final int inchesTenths = 0,
  final LogMeasurementStatus status = LogMeasurementStatus.loading,

  /// The unit shown.
  final LengthUnitPreference unit = LengthUnitPreference.centimeters,
}) extends Equatable {
  /// The wheels at [kind]'s defaults (Swift `defaultCentimetres`,
  /// `defaultInches`).
  factory initial(BodyMeasurementKind kind, DateTime date) =>
      LogMeasurementState(
        kind: kind,
        date: date,
        centimetres: kind.defaultCentimetres,
        inches: kind.defaultInches,
      );

  /// The reading to save, in centimetres, read from the wheels of [unit]
  /// (Swift `measurementCm`).
  double get centimetresValue => switch (unit) {
    LengthUnitPreference.centimeters => DecimalWheelValue.combine(
      whole: centimetres,
      tenths: centimetresTenths,
    ),
    LengthUnitPreference.inches =>
      DecimalWheelValue.combine(whole: inches, tenths: inchesTenths) *
          centimetresPerInch,
  };

  /// Whether the user can change anything or save.
  bool get isEditable =>
      status == LogMeasurementStatus.ready ||
      status == LogMeasurementStatus.failure;

  LogMeasurementState copyWith({
    DateTime? date,
    LogMeasurementStatus? status,
    LengthUnitPreference? unit,
  }) => LogMeasurementState(
    kind: kind,
    date: date ?? this.date,
    centimetres: centimetres,
    centimetresTenths: centimetresTenths,
    inches: inches,
    inchesTenths: inchesTenths,
    status: status ?? this.status,
    unit: unit ?? this.unit,
  );

  /// Both units' wheels set to [cm] centimetres, each whole number kept
  /// inside its wheel's span.
  LogMeasurementState withCentimetres(double cm) {
    final metric = _onWheel(cm, kind.centimetres);
    final imperial = _onWheel(cm / centimetresPerInch, kind.inches);
    return LogMeasurementState(
      kind: kind,
      date: date,
      centimetres: metric.whole,
      centimetresTenths: metric.tenths,
      inches: imperial.whole,
      inchesTenths: imperial.tenths,
      status: status,
      unit: unit,
    );
  }

  /// The wheels with [whole] on the whole-number wheel of [unit].
  LogMeasurementState withWhole(int whole) => switch (unit) {
    LengthUnitPreference.centimeters => withCentimetres(
      DecimalWheelValue.combine(whole: whole, tenths: centimetresTenths),
    ),
    LengthUnitPreference.inches => _withInches(
      DecimalWheelValue.combine(whole: whole, tenths: inchesTenths),
    ),
  };

  /// The wheels with [tenths] on the tenths wheel of [unit].
  LogMeasurementState withTenths(int tenths) => switch (unit) {
    LengthUnitPreference.centimeters => withCentimetres(
      DecimalWheelValue.combine(whole: centimetres, tenths: tenths),
    ),
    LengthUnitPreference.inches => _withInches(
      DecimalWheelValue.combine(whole: inches, tenths: tenths),
    ),
  };

  /// The inch wheels at [value] as turned, and the centimetre wheels
  /// converted from it.
  LogMeasurementState _withInches(double value) {
    final converted = withCentimetres(value * centimetresPerInch);
    final imperial = _onWheel(value, kind.inches);
    return LogMeasurementState(
      kind: kind,
      date: date,
      centimetres: converted.centimetres,
      centimetresTenths: converted.centimetresTenths,
      inches: imperial.whole,
      inchesTenths: imperial.tenths,
      status: status,
      unit: unit,
    );
  }

  @override
  List<Object> get props => [
    kind,
    date,
    centimetres,
    centimetresTenths,
    inches,
    inchesTenths,
    status,
    unit,
  ];
}

/// [value] split for the wheels, its whole part kept inside [range]: what
/// is shown is what is saved.
({int whole, int tenths}) _onWheel(double value, WheelRange range) {
  final (:whole, :tenths) = DecimalWheelValue.split(value);
  return (whole: whole.clamp(range.min, range.max), tenths: tenths);
}
