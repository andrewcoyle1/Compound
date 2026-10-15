part of 'weekly_check_in_bloc.dart';

/// Where the check-in has got to.
enum WeeklyCheckInStatus {
  /// Waiting for the week's data.
  loading,

  /// Showing a step.
  ready,

  /// The week's meals or weigh-ins could not be read.
  failure,

  /// Completed and recorded: the sheet closes.
  finished,
}

/// An alert the view shows once, when [WeeklyCheckInState.alertId] moves.
enum WeeklyCheckInAlert {
  /// "Unable to Log Weight".
  logWeightFailed,

  /// "Unable to Save Your Answer".
  saveFailed,

  /// "Unable to Complete Check-In".
  completeFailed,
}

/// The weekly check-in (Swift `CheckInPresenter`): the flow built once from
/// the week's data, the step showing, each list step's toggles, the
/// weigh-in's wheels, and the engine's figures, which stay live.
final class const WeeklyCheckInState({
  /// The ISO week the check-in reviews, which completing it records.
  required final DateTime weekStart,

  /// The weigh-in step's wheels, as Log Weight keeps them.
  required final LogWeightState weighIn,
  final WeeklyCheckInStatus status = WeeklyCheckInStatus.loading,

  /// The steps and the reviewed week, fixed once built.
  final CheckInFlow? flow,
  final int stepIndex = 0,

  /// The partial-logging step's rows, with their toggles.
  final List<CheckInDay> partialRows = const [],

  /// The fasting step's rows, with their toggles.
  final List<CheckInDay> fastingRows = const [],

  /// What the engine says now; recomputed as answers are saved.
  final ExpenditureFigures? figures,
  final bool isSaving = false,
  final WeeklyCheckInAlert? alert,

  /// Moves each time an [alert] should be shown.
  final int alertId = 0,
}) extends Equatable {
  /// The step showing, or null before the flow is built.
  CheckInStep? get currentStep {
    final steps = flow?.steps;
    if (steps == null || stepIndex >= steps.length) return null;
    return steps[stepIndex];
  }

  WeeklyCheckInState copyWith({
    LogWeightState? weighIn,
    WeeklyCheckInStatus? status,
    CheckInFlow? flow,
    int? stepIndex,
    List<CheckInDay>? partialRows,
    List<CheckInDay>? fastingRows,
    ExpenditureFigures? figures,
    bool? isSaving,
    WeeklyCheckInAlert? alert,
    int? alertId,
  }) => WeeklyCheckInState(
    weekStart: weekStart,
    weighIn: weighIn ?? this.weighIn,
    status: status ?? this.status,
    flow: flow ?? this.flow,
    stepIndex: stepIndex ?? this.stepIndex,
    partialRows: partialRows ?? this.partialRows,
    fastingRows: fastingRows ?? this.fastingRows,
    figures: figures ?? this.figures,
    isSaving: isSaving ?? this.isSaving,
    alert: alert ?? this.alert,
    alertId: alertId ?? this.alertId,
  );

  @override
  List<Object?> get props => [
    weekStart,
    weighIn,
    status,
    flow,
    stepIndex,
    partialRows,
    fastingRows,
    figures,
    isSaving,
    alert,
    alertId,
  ];
}
