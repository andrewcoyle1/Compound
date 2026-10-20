part of 'nutrition_overview_bloc.dart';

sealed class NutritionOverviewEvent extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// The screen opened: follow the day's meals and the engine's data.
final class NutritionOverviewStarted extends NutritionOverviewEvent {
  const new();
}

/// The Contributors switch.
final class const NutritionOverviewContributorsToggled({required final bool on})
    extends NutritionOverviewEvent {
  @override
  List<Object?> get props => [on];
}

/// Start on the check-in card; the view opens the check-in.
final class NutritionOverviewCheckInStarted extends NutritionOverviewEvent {
  const new();
}

/// Skip This Week on the check-in card.
final class NutritionOverviewCheckInSkipped extends NutritionOverviewEvent {
  const new();
}

/// Accept on the proposal card.
final class NutritionOverviewProposalAccepted extends NutritionOverviewEvent {
  const new();
}

/// Not now on the proposal card.
final class NutritionOverviewProposalDismissed extends NutritionOverviewEvent {
  const new();
}
