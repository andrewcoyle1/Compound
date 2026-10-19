import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// The gym editors' words and figures (Swift `GymEquipmentFormat` and the
/// screens' strings). `locale` is for tests.
abstract final class GymText {
  /// "1.25 kg": the weight as entered, with only the decimals it needs.
  static String weight(
    double value,
    ExerciseWeightUnit unit, {
    String? locale,
  }) =>
      '${AppFormat.number(value, maxFractionDigits: 2, locale: locale)} '
      '${WorkoutText.weightUnit(unit).symbol}';

  /// "5–100 kg, 2.5 kg increments".
  static String range(
    AppLocalizations l10n,
    WeightStack stack, {
    String? locale,
  }) {
    final lightest = stack.minWeight > 0 ? stack.minWeight : stack.increment;
    final from = AppFormat.number(
      lightest,
      maxFractionDigits: 2,
      locale: locale,
    );
    return l10n.gymRangeIncrements(
      '$from–${weight(stack.maxWeight, stack.unit, locale: locale)}',
      weight(stack.increment, stack.unit, locale: locale),
    );
  }

  /// A stack on one line: "5–300 lb, 5 lb increments · +2, +2", or
  /// "Uneven · 12 weights".
  static String stack(
    AppLocalizations l10n,
    WeightStack stack, {
    String? locale,
  }) {
    final weights = stack.weights;
    final pins = weights == null
        ? range(l10n, stack, locale: locale)
        : l10n.gymUnevenWeights(
            {
              for (final weight in weights)
                if (weight > 0) weight,
            }.length,
          );
    if (stack.addOns.isEmpty) return pins;
    final addOns = [
      for (final addOn in stack.addOns)
        '+${AppFormat.number(addOn, maxFractionDigits: 2, locale: locale)}',
    ];
    return '$pins · ${addOns.join(', ')}';
  }

  /// The weights switched on, lightest first in kilograms, as a row's
  /// detail.
  static String activeWeights(
    List<WeightEntry> entries, {
    String separator = ', ',
    String? locale,
  }) {
    double kilograms(WeightEntry entry) =>
        entry.unit == ExerciseWeightUnit.pounds
        ? entry.value / 2.20462
        : entry.value;
    final active = [
      for (final entry in entries)
        if (entry.isActive) entry,
    ];
    final indexed = [...active.indexed]
      ..sort((a, b) {
        final order = kilograms(a.$2).compareTo(kilograms(b.$2));
        return order != 0 ? order : a.$1.compareTo(b.$1);
      });
    return [
      for (final (_, entry) in indexed)
        weight(entry.value, entry.unit, locale: locale),
    ].join(separator);
  }

  /// A section's header.
  static String section(AppLocalizations l10n, GymEquipmentList list) =>
      switch (list) {
        GymEquipmentList.freeWeights => l10n.gymFreeWeights,
        GymEquipmentList.loadableBars => l10n.gymLoadableBars,
        GymEquipmentList.fixedWeightBars => l10n.gymFixedWeightBars,
        GymEquipmentList.bands => l10n.gymBands,
        GymEquipmentList.bodyWeights => l10n.gymBodyWeights,
        GymEquipmentList.supportEquipment => l10n.gymBenchesAndRacks,
        GymEquipmentList.accessoryEquipment => l10n.gymAccessories,
        GymEquipmentList.loadableAccessoryEquipment =>
          l10n.gymLoadableAccessories,
        GymEquipmentList.cableMachines => l10n.gymCableMachines,
        GymEquipmentList.plateLoadedMachines => l10n.gymPlateLoadedMachines,
        GymEquipmentList.pinLoadedMachines => l10n.gymPinLoadedMachines,
      };

  /// A row's edit link, or null for the lists with no editor.
  static String? editLink(AppLocalizations l10n, GymEquipmentList list) =>
      switch (list) {
        GymEquipmentList.freeWeights ||
        GymEquipmentList.loadableBars ||
        GymEquipmentList.fixedWeightBars ||
        GymEquipmentList.bodyWeights => l10n.gymEditWeights,
        GymEquipmentList.bands => l10n.gymEditInventory,
        GymEquipmentList.loadableAccessoryEquipment => l10n.gymEditBaseWeights,
        GymEquipmentList.cableMachines ||
        GymEquipmentList.pinLoadedMachines => l10n.gymEditMachine,
        GymEquipmentList.plateLoadedMachines => l10n.gymEditBaseWeight,
        GymEquipmentList.supportEquipment ||
        GymEquipmentList.accessoryEquipment => null,
      };

  /// What an Add screen says is missing.
  static String addWeightProblem(
    AppLocalizations l10n,
    AddWeightProblem problem,
  ) => switch (problem) {
    AddWeightProblem.notAboveZero => l10n.gymWeightAboveZero,
    AddWeightProblem.countBelowOne => l10n.gymCountAtLeastOne,
    AddWeightProblem.duplicate => l10n.gymWeightAlreadyAdded,
    AddWeightProblem.noName => l10n.gymWeightNeedsName,
  };

  /// What Add Range says is wrong.
  static String addStackProblem(
    AppLocalizations l10n,
    AddStackProblem problem,
  ) => switch (problem) {
    AddStackProblem.minNotBelowMax => l10n.gymLightestBelowHeaviest,
    AddStackProblem.noIncrement => l10n.gymIncrementAboveZero,
    AddStackProblem.nameTaken => l10n.gymRangeNameTaken,
    AddStackProblem.duplicate => l10n.gymRangeAlreadyAdded,
  };

  /// What Edit Range says about an add-on.
  static String addOnProblem(
    AppLocalizations l10n,
    StackWeightProblem problem,
  ) => switch (problem) {
    StackWeightProblem.tooManyAddOns => l10n.gymAddOnLimit(
      GymEditorRules.maxAddOns,
    ),
    _ => l10n.gymAddOnAboveZero,
  };

  /// What Edit Range says about a pin weight.
  static String pinWeightProblem(
    AppLocalizations l10n,
    StackWeightProblem problem,
  ) => switch (problem) {
    StackWeightProblem.duplicate => l10n.gymPinWeightOnStack,
    _ => l10n.gymPinWeightAboveZero,
  };

  /// The unit's name, for the empty state.
  static String unitName(AppLocalizations l10n, ExerciseWeightUnit unit) =>
      switch (unit) {
        ExerciseWeightUnit.kilograms => l10n.unitKilograms,
        ExerciseWeightUnit.pounds => l10n.unitPounds,
      };
}

/// The swatches the Add Band and Add Free Weight sheets offer, with the
/// hex Swift writes for each (`EquipmentColourPicker`).
enum EquipmentColour {
  /// Black in light mode, so named by what it is.
  standard('#000000'),
  red('#FF4245'),
  orange('#FF9230'),
  yellow('#FFD600'),
  green('#30D158'),
  blue('#0091FF'),
  purple('#DB34F2');

  new(this.hex);

  /// The stored colour.
  final String hex;

  /// Its name for screen readers.
  String label(AppLocalizations l10n) => switch (this) {
    standard => l10n.gymColourDefault,
    red => l10n.gymColourRed,
    orange => l10n.gymColourOrange,
    yellow => l10n.gymColourYellow,
    green => l10n.gymColourGreen,
    blue => l10n.gymColourBlue,
    purple => l10n.gymColourPurple,
  };
}
