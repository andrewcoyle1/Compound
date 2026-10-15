import 'package:bloc/bloc.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// The meal being built but not yet logged (Swift `MealLogManager
/// .draftMeal`), so closing the logger keeps the plate and Nutrition can
/// offer it again (`MealAccessoryPresenter`). Null when there is none.
///
/// ponytail: held in memory, so it is lost when the app is killed (Swift
/// keeps it on disk). Persist it when a device store lands in the app.
class MealDraftCubit extends Cubit<MealLogModel?> {
  new() : super(null);

  /// Keeps [meal] as the draft; an empty plate is no draft, so it clears.
  void keep(MealLogModel meal) => emit(meal.items.isEmpty ? null : meal);

  /// Forgets the draft: it was logged or discarded.
  void clear() => emit(null);
}
