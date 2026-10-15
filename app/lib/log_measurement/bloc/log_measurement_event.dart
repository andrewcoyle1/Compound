part of 'log_measurement_bloc.dart';

sealed class LogMeasurementEvent extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// The screen opened: start from the latest reading and the profile's
/// unit.
final class LogMeasurementStarted extends LogMeasurementEvent {
  const new();
}

/// The user picked the day the reading is for.
final class const LogMeasurementDateChanged(final DateTime date)
    extends LogMeasurementEvent {
  @override
  List<Object> get props => [date];
}

/// The user switched between centimetres and inches.
final class const LogMeasurementUnitChanged(final LengthUnitPreference unit)
    extends LogMeasurementEvent {
  @override
  List<Object> get props => [unit];
}

/// The user turned the whole-number wheel of the unit shown.
final class const LogMeasurementWholeChanged(final int whole)
    extends LogMeasurementEvent {
  @override
  List<Object> get props => [whole];
}

/// The user turned the tenths wheel of the unit shown.
final class const LogMeasurementTenthsChanged(final int tenths)
    extends LogMeasurementEvent {
  @override
  List<Object> get props => [tenths];
}

/// The user confirmed: save the reading.
final class LogMeasurementSaveRequested extends LogMeasurementEvent {
  const new();
}
