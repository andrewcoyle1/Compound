part of 'weekly_check_in_bloc.dart';

sealed class WeeklyCheckInEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// The sheet opened: follow the week's data and build the flow from it.
final class WeeklyCheckInStarted extends WeeklyCheckInEvent {
  const new();
}

/// A partial-logging row's toggle.
final class const WeeklyCheckInPartialToggled(
  final String dayKey, {
  required final bool on,
}) extends WeeklyCheckInEvent {
  @override
  List<Object?> get props => [dayKey, on];
}

/// A fasting row's toggle.
final class const WeeklyCheckInFastingToggled(
  final String dayKey, {
  required final bool on,
}) extends WeeklyCheckInEvent {
  @override
  List<Object?> get props => [dayKey, on];
}

/// The weigh-in's unit.
final class const WeeklyCheckInUnitChanged(final WeightUnitPreference unit)
    extends WeeklyCheckInEvent {
  @override
  List<Object?> get props => [unit];
}

/// The weigh-in's whole-number wheel.
final class const WeeklyCheckInWholeChanged(final int whole)
    extends WeeklyCheckInEvent {
  @override
  List<Object?> get props => [whole];
}

/// The weigh-in's tenths wheel.
final class const WeeklyCheckInTenthsChanged(final int tenths)
    extends WeeklyCheckInEvent {
  @override
  List<Object?> get props => [tenths];
}

/// Continue from whichever step is showing, saving what it collected, or
/// staying on a break, or declining one.
final class WeeklyCheckInContinuePressed extends WeeklyCheckInEvent {
  const new();
}

/// Log Weight on the weigh-in step.
final class WeeklyCheckInLogWeightPressed extends WeeklyCheckInEvent {
  const new();
}

/// Skip on the weigh-in step.
final class WeeklyCheckInSkipWeighInPressed extends WeeklyCheckInEvent {
  const new();
}

/// Start a Break.
final class WeeklyCheckInStartBreakPressed extends WeeklyCheckInEvent {
  const new();
}

/// End My Break.
final class WeeklyCheckInEndBreakPressed extends WeeklyCheckInEvent {
  const new();
}

/// Accept the target proposal, the flow's last step.
final class WeeklyCheckInAcceptPressed extends WeeklyCheckInEvent {
  const new();
}

/// Done, or Not Now on the proposal.
final class WeeklyCheckInDonePressed extends WeeklyCheckInEvent {
  const new();
}

/// The close button.
final class WeeklyCheckInDismissPressed extends WeeklyCheckInEvent {
  const new();
}
