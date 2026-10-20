part of 'nutrition_overview_bloc.dart';

/// An alert the view shows once, when [NutritionOverviewState.alertId]
/// moves.
enum NutritionOverviewAlert {
  /// "Unable to Update Your Targets".
  acceptFailed,

  /// "Unable to Skip Check-In".
  skipFailed,
}

/// The day's data and the engine's figures, as last read, with the cards
/// taken away while their writes are in flight.
final class const NutritionOverviewState({
  /// The day shown.
  required final String dayKey,
  final ExpenditureSnapshot? snapshot,
  final ExpenditureFigures? figures,
  final bool failed = false,
  final bool showsContributors = false,

  /// The proposal was accepted or dismissed here.
  final bool proposalHidden = false,
  final bool isApplyingProposal = false,

  /// This week's check-in was skipped here.
  final bool checkInSkipped = false,
  final NutritionOverviewAlert? alert,
  final int alertId = 0,
}) extends Equatable {
  /// Whether the data has arrived.
  bool get isLoaded => snapshot != null && figures != null;

  /// The day's meals.
  List<MealLogModel> get meals =>
      mealsOnDay(snapshot?.meals ?? const [], dayKey);

  /// What the day's meals add up to.
  Macros get totals => totalsOf(meals);

  /// The plan's target for the day, or null without a plan.
  Macros? get target => dailyTarget(snapshot?.dietPlan, dayKey);

  /// The week the check-in card offers, or null when none is waiting.
  DateTime? get dueCheckInWeekStart =>
      checkInSkipped ? null : figures?.dueCheckInWeekStart;

  /// The proposal the card offers, or null. It gives way to the check-in's
  /// card, whose last step it is.
  TargetProposal? get proposal =>
      proposalHidden || dueCheckInWeekStart != null ? null : figures?.proposal;

  NutritionOverviewState copyWith({
    ExpenditureSnapshot? snapshot,
    ExpenditureFigures? figures,
    bool? failed,
    bool? showsContributors,
    bool? proposalHidden,
    bool? isApplyingProposal,
    bool? checkInSkipped,
    NutritionOverviewAlert? alert,
    int? alertId,
  }) => NutritionOverviewState(
    dayKey: dayKey,
    snapshot: snapshot ?? this.snapshot,
    figures: figures ?? this.figures,
    failed: failed ?? this.failed,
    showsContributors: showsContributors ?? this.showsContributors,
    proposalHidden: proposalHidden ?? this.proposalHidden,
    isApplyingProposal: isApplyingProposal ?? this.isApplyingProposal,
    checkInSkipped: checkInSkipped ?? this.checkInSkipped,
    alert: alert ?? this.alert,
    alertId: alertId ?? this.alertId,
  );

  @override
  List<Object?> get props => [
    dayKey,
    snapshot,
    figures,
    failed,
    showsContributors,
    proposalHidden,
    isApplyingProposal,
    checkInSkipped,
    alert,
    alertId,
  ];
}
