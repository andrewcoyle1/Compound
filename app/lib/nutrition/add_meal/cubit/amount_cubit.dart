import 'package:bloc/bloc.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:food_repository/food_repository.dart';

/// An amount sheet's field and serving unit (Swift
/// `IngredientAmountPresenter` and `MealItemAmountViewPresenter`); the
/// figures are worked out by `meal_logging.dart`.
class AmountCubit extends Cubit<AmountState> {
  new(super.initialState);

  /// The field now reads [text].
  void textChanged(String text) =>
      emit(AmountState(text: text, unit: state.unit));

  /// The amount is now counted in [unit], or grams or millilitres when null.
  void unitChanged(ServingUnit? unit) => emit(state.withUnit(unit));
}
