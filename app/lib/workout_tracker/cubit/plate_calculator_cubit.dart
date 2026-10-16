import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show GymEditorRules, PlateChoice;
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

/// What the plate calculator opens on (`PlateCalculatorDelegate`).
final class const PlateCalculatorSetup({
  required final GymProfileModel gym,

  /// The bar or plate-loaded machine the exercise is loaded on.
  required final EquipmentRef equipment,
  required final ExerciseWeightUnit unit,

  /// The set's weight in [unit], or `null` when none is entered yet.
  required final double? total,

  /// A plate-loaded machine's base kept out of the set's load, in [unit].
  final double machineBase = 0,
});

/// The calculator's copy of the gym, which Done hands back.
final class const PlateCalculatorState(
  final PlateCalculatorSetup setup,
  final GymProfileModel gym,
) extends Equatable {
  ExerciseWeightUnit get unit => setup.unit;

  /// The set's load, as the set shows it: without a machine's base.
  double? get load => switch (setup.total) {
    final total? => ((total - setup.machineBase) * 1000).roundToDouble() / 1000,
    null => null,
  };

  /// What the keypad steps on with the gym as edited so far.
  r.WeightStep get step =>
      WeightStepper.steps([setup.equipment], gym, unit.rules);

  /// The loading of the set's weight, or the bare bar when there is none;
  /// `null` when these plates cannot make it.
  r.PlateLoading? get loading => r.PlateLoading.of(step, setup.total);

  /// The totals either side these plates can make, when they cannot make
  /// the set's weight; `null` when they can.
  r.NotLoadable? get notLoadable {
    final base = step.baseWeight;
    final total = setup.total;
    if (base == null || total == null) return null;
    return switch (r.PlateCalculator.load(
      total: total,
      bar: base,
      plates: step.plates,
      sleeves: step.sleeves,
    )) {
      final r.NotLoadable result => result,
      r.Loadable() => null,
    };
  }

  /// The bars switched on for this exercise, lightest first; none on a
  /// plate-loaded machine, whose base is fixed.
  List<BarBaseWeight> get barChoices =>
      setup.equipment.kind == EquipmentKind.loadableBar
      ? GymEditorRules.barChoices(gym, setup.equipment.equipmentId)
      : const [];

  /// The bar loaded now: the one chosen, else the heaviest switched on.
  String? get chosenBarId {
    final choices = barChoices;
    if (choices.isEmpty) return null;
    final chosen = GymEditorRules.loadedBar(
      gym,
      setup.equipment.equipmentId,
    )?.chosenBaseWeightId;
    if (choices.any((bar) => bar.id == chosen)) return chosen;
    // The heaviest, the first of equals, as the keypad loads it.
    double kilograms(BarBaseWeight bar) =>
        r.convertWeightToKg(bar.baseWeight, bar.unit.rules);
    var heaviest = choices.first;
    for (final bar in choices) {
      if (kilograms(heaviest) < kilograms(bar)) heaviest = bar;
    }
    return heaviest.id;
  }

  List<PlateChoice> get plateChoices => GymEditorRules.plateChoices(gym, unit);

  @override
  List<Object?> get props => [setup, gym];
}

/// The plate calculator behind the loading bar (`PlateCalculatorPresenter`):
/// how the set's weight goes on the bar, which bar the gym loads and which
/// plates it has. Edits a copy of the gym; Done hands it back, Close
/// changes nothing.
class PlateCalculatorCubit extends Cubit<PlateCalculatorState> {
  new(PlateCalculatorSetup setup, {required this._analytics})
    : super(PlateCalculatorState(setup, setup.gym)) {
    _analytics.appear(_screen);
  }

  static const _screen = 'PlateCalculatorView';

  final AnalyticsRepository _analytics;

  /// Loads bar [id] under every exercise on this bar at this gym.
  void barChosen(String id) {
    emit(
      PlateCalculatorState(
        state.setup,
        GymEditorRules.choosingBar(
          state.gym,
          id,
          typeId: state.setup.equipment.equipmentId,
        ),
      ),
    );
    _analytics.analytic('${_screen}_Bar_Chosen');
  }

  /// Switches every plate of [choice]'s weight off, or on.
  void plateToggled(PlateChoice choice) {
    emit(
      PlateCalculatorState(
        state.setup,
        GymEditorRules.settingPlate(
          state.gym,
          choice.weight,
          state.unit,
          isOn: !choice.isOn,
        ),
      ),
    );
    _analytics.analytic('${_screen}_Plate_Toggled');
  }

  /// Done: the gym as edited goes to the tracker to save.
  void done() => _analytics.analytic('${_screen}_Done');
}
