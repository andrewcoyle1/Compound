import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/training_library/logic/exercise_filters.dart';

/// The equipment ticked in the picker for one row of the equipment step
/// (Swift `EquipmentPickerPresenter`), in the order ticked.
class EquipmentPickerCubit extends Cubit<List<EquipmentKey>> {
  new({required List<EquipmentKey> chosen, required this._analytics})
    : super(chosen);

  static const _screen = 'EquipmentPickerView';

  final AnalyticsRepository _analytics;

  void appeared() => _analytics.appear(_screen);

  void disappeared() => _analytics.disappear(_screen);

  /// Ticks [key], or unticks it when it was ticked.
  void toggled(EquipmentKey key) => emit(
    state.contains(key)
        ? [
            for (final other in state)
              if (other != key) other,
          ]
        : [...state, key],
  );
}
