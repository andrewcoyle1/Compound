part of 'progress_bloc.dart';

sealed class ProgressEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// Start following everything the cards are built from.
final class ProgressSubscriptionRequested extends ProgressEvent {
  const new();
}

/// The user picked [range] on a metric chart's picker.
final class const ProgressRangeSelected(final MetricRange range)
    extends ProgressEvent {
  @override
  List<Object?> get props => [range];
}

/// The user deleted a reading: remove [fields] from the entry [entryId]
/// (Swift `onDeleteEntry`, which clears one value, not the entry).
final class const ProgressMeasurementCleared({
  required final String entryId,
  required final Set<String> fields,
}) extends ProgressEvent {
  @override
  List<Object?> get props => [entryId, fields];
}

/// The user pressed [day] (0 = the week's first) on the weekly target
/// grid.
final class const ProgressTargetDayPressed(final int day)
    extends ProgressEvent {
  @override
  List<Object?> get props => [day];
}

/// The current weight goal changed, or the user's goal id did.
final class const _ProgressGoalChanged(final WeightGoal? goal)
    extends ProgressEvent {
  @override
  List<Object?> get props => [goal];
}
