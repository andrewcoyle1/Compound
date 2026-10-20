import 'package:bloc/bloc.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';

/// Quick add's form (Swift `FoodItemQuickAddPresenter`).
class QuickAddCubit extends Cubit<QuickAddState> {
  new() : super(const QuickAddState());

  /// Log has put the item on the plate (see [QuickAddState.addedForLog]).
  void addedForLog() => emit(state.copyWith(addedForLog: true));

  void nameChanged(String name) => emit(state.copyWith(name: name));

  void energyChanged(double? value) =>
      emit(state.copyWith(energy: () => value));

  void energyUnitChanged(EnergyUnit unit) =>
      emit(state.copyWith(energyUnit: unit));

  void proteinChanged(double? value) =>
      emit(state.copyWith(protein: () => value));

  void carbsChanged(double? value) => emit(state.copyWith(carbs: () => value));

  void fatChanged(double? value) => emit(state.copyWith(fat: () => value));

  void alcoholChanged(double? value) =>
      emit(state.copyWith(alcohol: () => value));

  void macroUnitChanged(MacroUnit unit) =>
      emit(state.copyWith(macroUnit: unit));
}
