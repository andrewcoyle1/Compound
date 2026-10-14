part of 'nutrition_day_bloc.dart';

sealed class NutritionDayEvent extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// Start following the user's meals, diet plan and food log settings.
final class NutritionDaySubscriptionRequested extends NutritionDayEvent {
  const new();
}

/// The user picked [day] on the calendar strip.
final class const NutritionDayDateSelected(final DateTime day)
    extends NutritionDayEvent {
  @override
  List<Object> get props => [day];
}
