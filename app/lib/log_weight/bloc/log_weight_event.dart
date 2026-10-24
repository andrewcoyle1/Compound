part of 'log_weight_bloc.dart';

sealed class LogWeightEvent extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// The screen opened: start from the latest weigh-in and the profile's
/// unit.
final class LogWeightStarted extends LogWeightEvent {
  const new();
}

/// The user picked the day the weigh-in is for.
final class const LogWeightDateChanged(final DateTime date)
    extends LogWeightEvent {
  @override
  List<Object> get props => [date];
}

/// The user switched between kilograms and pounds.
final class const LogWeightUnitChanged(final WeightUnitPreference unit)
    extends LogWeightEvent {
  @override
  List<Object> get props => [unit];
}

/// The user turned the whole-number wheel of the unit shown.
final class const LogWeightWholeChanged(final int whole)
    extends LogWeightEvent {
  @override
  List<Object> get props => [whole];
}

/// The user turned the tenths wheel of the unit shown.
final class const LogWeightTenthsChanged(final int tenths)
    extends LogWeightEvent {
  @override
  List<Object> get props => [tenths];
}

/// The user confirmed: save the weigh-in, or [weight], typed in the unit
/// shown, as the wheels would hold it.
final class const LogWeightSaveRequested([final double? weight])
    extends LogWeightEvent {
  @override
  List<Object> get props => [?weight];
}
