import 'dart:math';

import 'package:compound_models/compound_models.dart';

/// A stored item or entry, as Firestore holds it.
typedef StoredMap = Map<String, Object?>;

/// One equipment list of a gym profile, by the key it is stored under.
enum GymEquipmentList {
  /// Dumbbells, kettlebells, plates.
  freeWeights(GymProfileModelKeys.freeWeights),

  /// Bars that take plates.
  loadableBars(GymProfileModelKeys.loadableBars),

  /// Bars that come at a fixed weight.
  fixedWeightBars(GymProfileModelKeys.fixedWeightBars),

  /// Resistance bands.
  bands(GymProfileModelKeys.bands),

  /// Vests and belts that add to body weight.
  bodyWeights(GymProfileModelKeys.bodyWeights),

  /// Benches, racks and stations.
  supportEquipment(GymProfileModelKeys.supportEquipment),

  /// Accessories.
  accessoryEquipment(GymProfileModelKeys.accessoryEquipment),

  /// Accessories that take plates.
  loadableAccessoryEquipment(GymProfileModelKeys.loadableAccessoryEquipment),

  /// Cable machines.
  cableMachines(GymProfileModelKeys.cableMachines),

  /// Plate-loaded machines.
  plateLoadedMachines(GymProfileModelKeys.plateLoadedMachines),

  /// Pin-loaded machines.
  pinLoadedMachines(GymProfileModelKeys.pinLoadedMachines);

  new(this.key);

  /// The gym profile field the list is stored in.
  final String key;

  /// The kind of equipment an exercise names this list's items by.
  EquipmentKind get kind => switch (this) {
    freeWeights => EquipmentKind.freeWeight,
    loadableBars => EquipmentKind.loadableBar,
    fixedWeightBars => EquipmentKind.fixedWeightBar,
    bands => EquipmentKind.bands,
    bodyWeights => EquipmentKind.bodyWeight,
    supportEquipment => EquipmentKind.supportEquipment,
    accessoryEquipment => EquipmentKind.accessoryEquipment,
    loadableAccessoryEquipment => EquipmentKind.loadableAccessoryEquipment,
    cableMachines => EquipmentKind.cableMachine,
    plateLoadedMachines => EquipmentKind.plateLoadedMachine,
    pinLoadedMachines => EquipmentKind.pinLoadedMachine,
  };

  /// The list in [gym].
  List<GymEquipmentItem> of(GymProfileModel gym) => switch (this) {
    freeWeights => gym.freeWeights,
    loadableBars => gym.loadableBars,
    fixedWeightBars => gym.fixedWeightBars,
    bands => gym.bands,
    bodyWeights => gym.bodyWeights,
    supportEquipment => gym.supportEquipment,
    accessoryEquipment => gym.accessoryEquipment,
    loadableAccessoryEquipment => gym.loadableAccessoryEquipment,
    cableMachines => gym.cableMachines,
    plateLoadedMachines => gym.plateLoadedMachines,
    pinLoadedMachines => gym.pinLoadedMachines,
  };

  /// The catalogue's items of this list.
  List<GymEquipmentItem> get catalogue {
    final catalogue = GymEquipmentCatalogue.instance;
    return switch (this) {
      freeWeights => catalogue.freeWeights,
      loadableBars => catalogue.loadableBars,
      fixedWeightBars => catalogue.fixedWeightBars,
      bands => catalogue.bands,
      bodyWeights => catalogue.bodyWeights,
      supportEquipment => catalogue.supportEquipment,
      accessoryEquipment => catalogue.accessoryEquipment,
      loadableAccessoryEquipment => catalogue.loadableAccessoryEquipment,
      cableMachines => catalogue.cableMachines,
      plateLoadedMachines => catalogue.plateLoadedMachines,
      pinLoadedMachines => catalogue.pinLoadedMachines,
    };
  }

  /// Reads one item of this list.
  GymEquipmentItem decode(StoredMap data) => switch (this) {
    freeWeights => FreeWeights.fromFirestore(data),
    loadableBars => LoadableBars.fromFirestore(data),
    fixedWeightBars => FixedWeightBars.fromFirestore(data),
    bands => Bands.fromFirestore(data),
    bodyWeights => BodyWeights.fromFirestore(data),
    supportEquipment ||
    accessoryEquipment => PlainEquipment.fromFirestore(data),
    loadableAccessoryEquipment => LoadableAccessoryEquipment.fromFirestore(
      data,
    ),
    cableMachines || pinLoadedMachines => StackMachine.fromFirestore(data),
    plateLoadedMachines => PlateLoadedMachine.fromFirestore(data),
  };

  /// A list the user can add to, duplicate in and delete their own from
  /// (Swift `CustomizableMachine`).
  bool get isMachine =>
      this == cableMachines ||
      this == pinLoadedMachines ||
      this == plateLoadedMachines;

  /// The field holding the item's weights, for the lists edited as a list of
  /// weights or stacks; null for the rest.
  String? get entriesKey => switch (this) {
    freeWeights || bodyWeights || bands => GymEquipmentKeys.range,
    loadableBars || fixedWeightBars => GymEquipmentKeys.baseWeights,
    cableMachines || pinLoadedMachines => GymEquipmentKeys.ranges,
    _ => null,
  };

  /// The field of each weight holding its figure, for the weight lists.
  String? get valueKey => switch (this) {
    freeWeights || bodyWeights => GymEquipmentKeys.availableWeights,
    bands => GymEquipmentKeys.availableResistance,
    loadableBars || fixedWeightBars => GymEquipmentKeys.baseWeight,
    _ => null,
  };
}

/// One weight of a weight list, read from its stored map: a free weight, a
/// body weight, a band or a bar's base weight.
final class const WeightEntry({
  /// The entry's id.
  required final String id,

  /// The weight, or a band's resistance.
  required final double value,

  /// Its unit.
  required final ExerciseWeightUnit unit,

  /// Whether the gym has it.
  required final bool isActive,

  /// A plate's or band's colour, as a hex string.
  final String? colour,

  /// A band's label.
  final String? name,

  /// How many of a plate the gym has; null is no limit.
  final int? count,
}) {
  /// Creates a [WeightEntry].
  this;
}

/// Equipment as exercises name it: its kind and catalogue type.
typedef EquipmentScope = Set<(EquipmentKind kind, String typeId)>;

/// One plate weight the plate calculator offers, in the unit it is shown
/// in, and whether the gym has it switched on (`PlateChoice`).
typedef PlateChoice = ({double weight, bool isOn});

/// Why a weight cannot be added yet (the Add screens' `validationMessage`).
enum AddWeightProblem {
  /// "Enter a weight above zero."
  notAboveZero,

  /// "Enter at least one, or leave it empty for no limit."
  countBelowOne,

  /// "This weight is already added."
  duplicate,

  /// "Please enter a name for this weight."
  noName,
}

/// Why a stack cannot be added yet (`AddWeightStackPresenter`).
enum AddStackProblem {
  /// "The lightest pin must be less than the heaviest."
  minNotBelowMax,

  /// "The increment must be greater than zero."
  noIncrement,

  /// "A range with this name already exists."
  nameTaken,

  /// "This range is already added."
  duplicate,
}

/// Why an add-on or pin weight cannot be added (`EditWeightRangePresenter`).
enum StackWeightProblem {
  /// "An add-on must weigh more than zero." / "A pin weight must be more
  /// than zero."
  notAboveZero,

  /// "A stack can have up to 6 add-ons."
  tooManyAddOns,

  /// "This weight is already on the stack."
  duplicate,
}

/// The gym editors' rules: Swift's `GymProfilePresenter` and the equipment
/// editors' presenters, and `GymProfileModel+Machines.swift`. Every change
/// returns a new profile; the models have no copies of their own, so items
/// are changed through their stored maps.
abstract final class GymEditorRules {
  /// The most add-ons a stack takes (`WeightStack.maxAddOns`).
  static const maxAddOns = 6;

  static const _poundsPerKilogram = 2.20462;

  // MARK: - The gym

  /// [gym] with [changes] over its stored fields.
  static GymProfileModel _with(GymProfileModel gym, StoredMap changes) =>
      GymProfileModel.fromFirestore({...gym.toFirestore(), ...changes});

  /// [gym] renamed.
  static GymProfileModel renamed(GymProfileModel gym, String name) =>
      _with(gym, {GymProfileModelKeys.name: name});

  /// [gym] with [list] replaced by [items].
  static GymProfileModel withItems(
    GymProfileModel gym,
    GymEquipmentList list,
    List<GymEquipmentItem> items,
  ) => _with(gym, {
    list.key: [for (final item in items) item.toFirestore()],
  });

  /// The item [id] of [list], or null when it is gone.
  static GymEquipmentItem? item(
    GymProfileModel gym,
    GymEquipmentList list,
    String id,
  ) => list.of(gym).where((item) => item.id == id).firstOrNull;

  /// [gym] with [edit] applied to the stored map of item [id]; unchanged
  /// when it is gone, so a row mid-removal writes nothing.
  static GymProfileModel updatingItem(
    GymProfileModel gym,
    GymEquipmentList list,
    String id,
    StoredMap Function(StoredMap item) edit,
  ) => withItems(gym, list, [
    for (final item in list.of(gym))
      if (item.id == id) list.decode(edit(item.toFirestore())) else item,
  ]);

  /// [gym] with item [id] switched on or off.
  static GymProfileModel settingActive(
    GymProfileModel gym,
    GymEquipmentList list,
    String id, {
    required bool isActive,
  }) => updatingItem(gym, list, id, (item) {
    return {...item, GymEquipmentKeys.isActive: isActive};
  });

  /// [list]'s items that match [query] (trimmed, any case) and, with
  /// [selectedOnly], are switched on, by name and then as stored.
  /// With [scope], only the items it names: one exercise variation's
  /// equipment, edited from inside a workout.
  static List<GymEquipmentItem> visibleItems(
    GymProfileModel gym,
    GymEquipmentList list, {
    String query = '',
    bool selectedOnly = false,
    EquipmentScope? scope,
  }) {
    final needle = query.trim().toLowerCase();
    final items = [
      for (final item in list.of(gym))
        if ((needle.isEmpty || _name(item).toLowerCase().contains(needle)) &&
            (!selectedOnly || item.isActive) &&
            (scope?.contains((list.kind, item.typeId)) ?? true))
          item,
    ];
    return _stableSorted(
      items,
      (a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()),
    );
  }

  /// Whether a query hides every list (`hasNoMatchingEquipment`): only a
  /// real query can.
  static bool hidesEverything(
    GymProfileModel gym, {
    required String query,
    required bool selectedOnly,
    EquipmentScope? scope,
  }) =>
      query.trim().isNotEmpty &&
      GymEquipmentList.values.every(
        (list) => visibleItems(
          gym,
          list,
          query: query,
          selectedOnly: selectedOnly,
          scope: scope,
        ).isEmpty,
      );

  static String _name(GymEquipmentItem item) =>
      item.toFirestore()[GymEquipmentKeys.name]! as String;

  /// An item's name.
  static String nameOf(GymEquipmentItem item) => _name(item);

  static List<T> _stableSorted<T>(List<T> items, int Function(T, T) compare) {
    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])]
      ..sort((a, b) {
        final order = compare(a.$2, b.$2);
        return order != 0 ? order : a.$1.compareTo(b.$1);
      });
    return [for (final (_, item) in indexed) item];
  }

  // MARK: - Weight lists

  static List<StoredMap> _entries(GymEquipmentItem item, String key) => [
    for (final entry in item.toFirestore()[key]! as List<Object?>)
      entry! as StoredMap,
  ];

  static WeightEntry _entry(GymEquipmentList list, StoredMap data) =>
      WeightEntry(
        id: data[GymEquipmentKeys.id]! as String,
        value: (data[list.valueKey]! as num).toDouble(),
        unit: enumFromValue(
          ExerciseWeightUnit.values,
          data[GymEquipmentKeys.unit]! as String,
        ),
        isActive: data[GymEquipmentKeys.isActive]! as bool,
        colour:
            data[GymEquipmentKeys.plateColour] as String? ??
            data[GymEquipmentKeys.bandColour] as String?,
        name: list == GymEquipmentList.bands
            ? data[GymEquipmentKeys.name] as String?
            : null,
        count: data[GymEquipmentKeys.count] as int?,
      );

  /// Every weight of a weight-list [item].
  static List<WeightEntry> allWeights(
    GymEquipmentList list,
    GymEquipmentItem item,
  ) => [
    for (final data in _entries(item, list.entriesKey!)) _entry(list, data),
  ];

  /// The weights of [item] in [unit], lightest first, as the editors list
  /// them.
  static List<WeightEntry> weights(
    GymEquipmentList list,
    GymEquipmentItem item,
    ExerciseWeightUnit unit,
  ) => _stableSorted([
    for (final entry in allWeights(list, item))
      if (entry.unit == unit) entry,
  ], (a, b) => a.value.compareTo(b.value));

  /// The unit an editor opens on: a bar rack's default bar's, else
  /// kilograms.
  static ExerciseWeightUnit openingUnit(
    GymEquipmentList list,
    GymEquipmentItem item,
  ) {
    final defaultId = switch (item) {
      LoadableBars(:final defaultBaseWeightId) => defaultBaseWeightId,
      FixedWeightBars(:final defaultBaseWeightId) => defaultBaseWeightId,
      StackMachine(:final defaultRangeId) => defaultRangeId,
      _ => null,
    };
    for (final entry in _entries(item, list.entriesKey!)) {
      if (entry[GymEquipmentKeys.id] == defaultId) {
        return enumFromValue(
          ExerciseWeightUnit.values,
          entry[GymEquipmentKeys.unit]! as String,
        );
      }
    }
    return ExerciseWeightUnit.kilograms;
  }

  /// [gym] with [edit] applied to entry [entryId] of item [itemId]; nothing
  /// changes when either is gone.
  static GymProfileModel updatingEntry(
    GymProfileModel gym,
    GymEquipmentList list,
    String itemId,
    String entryId,
    StoredMap Function(StoredMap entry) edit,
  ) => updatingItem(gym, list, itemId, (item) {
    final key = list.entriesKey!;
    return {
      ...item,
      key: [
        for (final entry in (item[key]! as List<Object?>).cast<StoredMap>())
          if (entry[GymEquipmentKeys.id] == entryId) edit(entry) else entry,
      ],
    };
  });

  /// [gym] with the entries [ids] of item [itemId] removed. A stack
  /// machine's default moves to the first remaining active stack, else the
  /// first, else none (`StackMachine.removeStacks`).
  static GymProfileModel deletingEntries(
    GymProfileModel gym,
    GymEquipmentList list,
    String itemId,
    Set<String> ids,
  ) => updatingItem(gym, list, itemId, (item) {
    final key = list.entriesKey!;
    final remaining = [
      for (final entry in (item[key]! as List<Object?>).cast<StoredMap>())
        if (!ids.contains(entry[GymEquipmentKeys.id])) entry,
    ];
    final updated = {...item, key: remaining};
    final current = item[GymEquipmentKeys.defaultRangeId];
    if (key == GymEquipmentKeys.ranges && ids.contains(current)) {
      final next =
          remaining
              .where((stack) => stack[GymEquipmentKeys.isActive] == true)
              .firstOrNull ??
          remaining.firstOrNull;
      if (next == null) {
        updated.remove(GymEquipmentKeys.defaultRangeId);
      } else {
        updated[GymEquipmentKeys.defaultRangeId] = next[GymEquipmentKeys.id];
      }
    }
    return updated;
  });

  /// [gym] with [entry] appended to item [itemId]. The first stack a
  /// machine gets becomes its default (`StackMachine.addStack`).
  static GymProfileModel addingEntry(
    GymProfileModel gym,
    GymEquipmentList list,
    String itemId,
    StoredMap entry,
  ) => updatingItem(gym, list, itemId, (item) {
    final key = list.entriesKey!;
    return {
      ...item,
      key: [...item[key]! as List<Object?>, entry],
      if (key == GymEquipmentKeys.ranges &&
          item[GymEquipmentKeys.defaultRangeId] == null)
        GymEquipmentKeys.defaultRangeId: entry[GymEquipmentKeys.id],
    };
  });

  /// A plate count as its field gives it: empty is no limit, and anything
  /// else is rounded down to a whole, non-negative number.
  static int? plateCount(double? field) =>
      field == null ? null : max(field, 0).floor();

  /// Why a new weight of [list] cannot be added to [item] yet, or null when
  /// it can. Each Add screen checks what its Swift presenter does, in its
  /// order: free weights and bars need a weight above zero, free weights a
  /// count of at least one when given, bands a name, and none a figure
  /// already held in the same unit.
  static AddWeightProblem? addWeightProblem(
    GymEquipmentList list,
    GymEquipmentItem item, {
    required double value,
    required ExerciseWeightUnit unit,
    int? count,
    String name = '',
  }) {
    final needsWeight =
        list == GymEquipmentList.freeWeights ||
        list == GymEquipmentList.loadableBars ||
        list == GymEquipmentList.fixedWeightBars;
    if (needsWeight && value <= 0) return AddWeightProblem.notAboveZero;
    if (list == GymEquipmentList.freeWeights && count != null && count < 1) {
      return AddWeightProblem.countBelowOne;
    }
    final held = allWeights(
      list,
      item,
    ).any((entry) => entry.value == value && entry.unit == unit);
    if (held) return AddWeightProblem.duplicate;
    if (list == GymEquipmentList.bands && name.isEmpty) {
      return AddWeightProblem.noName;
    }
    return null;
  }

  /// A new weight of [list] as its Add screen builds it, switched on.
  static StoredMap newWeight(
    GymEquipmentList list, {
    required String id,
    required double value,
    required ExerciseWeightUnit unit,
    String? colour,
    String name = '',
    int? count,
  }) => {
    GymEquipmentKeys.id: id,
    list.valueKey!: value,
    GymEquipmentKeys.unit: unit.value,
    GymEquipmentKeys.isActive: true,
    if (list == GymEquipmentList.bands) ...{
      GymEquipmentKeys.name: name,
      GymEquipmentKeys.bandColour: colour,
    } else
      GymEquipmentKeys.plateColour: ?colour,
    GymEquipmentKeys.count: ?count,
  };

  /// One collar of [bar] in [unit], to three places, or null for none.
  /// Collars are stored in kilograms.
  static double? collarShown(LoadableBars bar, ExerciseWeightUnit unit) {
    if (bar.collarWeight <= 0) return null;
    final shown = unit == ExerciseWeightUnit.pounds
        ? bar.collarWeight * _poundsPerKilogram
        : bar.collarWeight;
    return (shown * 1000).roundToDouble() / 1000;
  }

  /// A collar typed in [unit], as stored: kilograms, never below nothing.
  static double collarStored(double? value, ExerciseWeightUnit unit) {
    final typed = value ?? 0;
    final kilograms = unit == ExerciseWeightUnit.pounds
        ? typed / _poundsPerKilogram
        : typed;
    return max(kilograms, 0);
  }

  // MARK: - Stacks

  /// [machine]'s stacks in [unit], by name and then id, so the list does
  /// not reshuffle as stacks come and go.
  static List<WeightStack> stacks(
    StackMachine machine,
    ExerciseWeightUnit unit,
  ) {
    final stacks = [
      for (final stack in machine.ranges)
        if (stack.unit == unit) stack,
    ];
    return stacks..sort((a, b) {
      final order = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return order != 0 ? order : a.id.compareTo(b.id);
    });
  }

  /// [stack] with [edit] applied to its stored map.
  static WeightStack editedStack(
    WeightStack stack,
    StoredMap Function(StoredMap stack) edit,
  ) => WeightStack.fromFirestore(edit(stack.toFirestore()));

  /// A new stack as Add Range opens it: 2.5 to 150 in steps of 2.5, or 5
  /// to 150 in fives for pounds.
  static WeightStack newStack({
    required String id,
    required ExerciseWeightUnit unit,
  }) {
    final step = unit == ExerciseWeightUnit.pounds ? 5.0 : 2.5;
    return WeightStack(
      id: id,
      name: '',
      minWeight: step,
      maxWeight: 150,
      increment: step,
      unit: unit,
      isActive: true,
    );
  }

  /// Why [draft] cannot be added beside [existing] yet, or null.
  static AddStackProblem? addStackProblem(
    List<WeightStack> existing,
    WeightStack draft,
  ) {
    if (draft.minWeight >= draft.maxWeight) {
      return AddStackProblem.minNotBelowMax;
    }
    if (draft.increment <= 0) return AddStackProblem.noIncrement;
    final name = draft.name.trim().toLowerCase();
    if (existing.any((stack) => stack.name.trim().toLowerCase() == name)) {
      return AddStackProblem.nameTaken;
    }
    final same = existing.any(
      (stack) =>
          stack.minWeight == draft.minWeight &&
          stack.maxWeight == draft.maxWeight &&
          stack.increment == draft.increment &&
          stack.unit == draft.unit,
    );
    return same ? AddStackProblem.duplicate : null;
  }

  /// Why the add-on [value] cannot go on [stack], or null; two equal
  /// add-ons are allowed.
  static StackWeightProblem? addOnProblem(WeightStack stack, double value) {
    if (value <= 0) return StackWeightProblem.notAboveZero;
    if (stack.addOns.length >= maxAddOns) {
      return StackWeightProblem.tooManyAddOns;
    }
    return null;
  }

  /// Why the pin weight [value] cannot go on [stack], or null.
  static StackWeightProblem? pinWeightProblem(WeightStack stack, double value) {
    if (value <= 0) return StackWeightProblem.notAboveZero;
    final held = (stack.weights ?? const <double>[]).any(
      (weight) => (weight - value).abs() < 0.0001,
    );
    return held ? StackWeightProblem.duplicate : null;
  }

  /// [stack] with the add-on [value] added.
  static WeightStack addingAddOn(WeightStack stack, double value) =>
      editedStack(stack, (data) {
        return {
          ...data,
          GymEquipmentKeys.addOns: [...stack.addOns, value],
        };
      });

  /// [stack] with the add-ons at [indices] removed.
  static WeightStack removingAddOns(WeightStack stack, Set<int> indices) =>
      editedStack(stack, (data) {
        return {
          ...data,
          GymEquipmentKeys.addOns: [
            for (var i = 0; i < stack.addOns.length; i++)
              if (!indices.contains(i)) stack.addOns[i],
          ],
        };
      });

  /// [stack] made uneven (a pin-weight list, kept if it had one) or even.
  static WeightStack settingUneven(
    WeightStack stack, {
    required bool isUneven,
  }) => editedStack(stack, (data) {
    final updated = {...data};
    if (isUneven) {
      updated[GymEquipmentKeys.weights] = stack.weights ?? const <double>[];
    } else {
      updated.remove(GymEquipmentKeys.weights);
    }
    return updated;
  });

  /// [stack] with the pin weight [value] added, in order.
  static WeightStack addingPinWeight(WeightStack stack, double value) =>
      editedStack(stack, (data) {
        return {
          ...data,
          GymEquipmentKeys.weights: [...?stack.weights, value]..sort(),
        };
      });

  /// [stack] with the pin weights at [indices] removed.
  static WeightStack removingPinWeights(WeightStack stack, Set<int> indices) {
    final weights = stack.weights ?? const <double>[];
    return editedStack(stack, (data) {
      return {
        ...data,
        GymEquipmentKeys.weights: [
          for (var i = 0; i < weights.length; i++)
            if (!indices.contains(i)) weights[i],
        ],
      };
    });
  }

  /// Whether [stack] is one [repaired] would change.
  static bool needsRepair(WeightStack stack) =>
      stack.maxWeight < stack.minWeight ||
      stack.increment <= 0 ||
      (stack.weights?.isEmpty ?? false);

  /// [stack] put back into a state weights can be picked from, as Edit
  /// Range leaves it (`repairRange`): ends the wrong way round are swapped,
  /// an unusable increment goes back to [openingIncrement] (or the unit's
  /// usual step), and an empty uneven list goes back to the grid.
  static WeightStack repaired(WeightStack stack, double openingIncrement) =>
      editedStack(stack, (data) {
        final updated = {...data};
        if (stack.maxWeight < stack.minWeight) {
          updated[GymEquipmentKeys.minWeight] = stack.maxWeight;
          updated[GymEquipmentKeys.maxWeight] = stack.minWeight;
        }
        if (stack.increment <= 0) {
          updated[GymEquipmentKeys.increment] = openingIncrement > 0
              ? openingIncrement
              : (stack.unit == ExerciseWeightUnit.pounds ? 5.0 : 2.5);
        }
        if (stack.weights?.isEmpty ?? false) {
          updated.remove(GymEquipmentKeys.weights);
        }
        return updated;
      });

  // MARK: - Machines

  /// Whether [item] of [list] is the user's own or a duplicate, which alone
  /// can be renamed and deleted: a catalogue item would come back on the
  /// next read.
  static bool isCustom(GymEquipmentList list, GymEquipmentItem item) =>
      !list.catalogue.any((catalogue) => catalogue.id == item.id);

  /// "Lat Pulldown 2", or the first number after it [taken] lacks.
  /// [numbered] spells a name and number, as the app's strings do.
  static String nextFreeName(
    String name,
    Set<String> taken, {
    String Function(String name, int number)? numbered,
  }) {
    final spell = numbered ?? (name, number) => '$name $number';
    var number = 2;
    while (taken.contains(spell(name, number))) {
      number++;
    }
    return spell(name, number);
  }

  /// [gym] with a copy of machine [id] after it, under a new id and the
  /// next free name, keeping its type; and the copy's id, or null when
  /// [id] is gone.
  static (GymProfileModel, String?) duplicatingMachine(
    GymProfileModel gym,
    GymEquipmentList list,
    String id, {
    required String Function() newId,
    String Function(String name, int number)? numbered,
  }) {
    final items = list.of(gym);
    final index = items.indexWhere((item) => item.id == id);
    if (index < 0) return (gym, null);
    final copyId = newId();
    final original = items[index];
    final copy = list.decode({
      ...original.toFirestore(),
      GymEquipmentKeys.id: copyId,
      GymEquipmentKeys.name: nextFreeName(_name(original), {
        for (final item in items) _name(item),
      }, numbered: numbered),
    });
    return (withItems(gym, list, [...items]..insert(index + 1, copy)), copyId);
  }

  /// [gym] with a new machine of [list] named [name], switched on, and its
  /// id. With [worksAs], a catalogue type of that list, it takes that
  /// type's loading and stands in for it; without, it is its own type and
  /// takes the first catalogue machine's stacks (or a bare 0 kg plate-loaded
  /// machine).
  static (GymProfileModel, String) addingMachine(
    GymProfileModel gym,
    GymEquipmentList list, {
    required String name,
    required String Function() newId,
    String? worksAs,
  }) {
    final template = list.catalogue
        .where((item) => item.id == worksAs)
        .firstOrNull;
    final standalone = list == GymEquipmentList.plateLoadedMachines
        ? const PlateLoadedMachine(
            id: '',
            typeId: '',
            name: '',
            baseWeight: 0,
            unit: ExerciseWeightUnit.kilograms,
            sleeves: 2,
            excludesBaseFromLoad: true,
            isActive: true,
          ).toFirestore()
        : list.catalogue.first.toFirestore();
    final id = newId();
    final machine = list.decode({
      ...template?.toFirestore() ?? standalone,
      GymEquipmentKeys.id: id,
      GymEquipmentKeys.typeId: template?.id ?? id,
      GymEquipmentKeys.name: name,
      GymEquipmentKeys.isActive: true,
    });
    return (withItems(gym, list, [...list.of(gym), machine]), id);
  }

  /// [gym] without machine [id] if the user made it; a catalogue machine
  /// only switches off.
  static GymProfileModel deletingMachine(
    GymProfileModel gym,
    GymEquipmentList list,
    String id,
  ) => withItems(gym, list, [
    for (final item in list.of(gym))
      if (item.id != id || !isCustom(list, item)) item,
  ]);

  /// [gym] with machine [id]'s name put back to [original] when it was left
  /// blank, as its editor does on leaving.
  static GymProfileModel restoringBlankName(
    GymProfileModel gym,
    GymEquipmentList list,
    String id,
    String original,
  ) {
    final machine = item(gym, list, id);
    if (machine == null || _name(machine).trim().isNotEmpty) return gym;
    return updatingItem(gym, list, id, (data) {
      return {...data, GymEquipmentKeys.name: original};
    });
  }

  // MARK: - Loading (`GymProfileModel+Loading`)

  /// The bar loaded for exercises naming [typeId]: the first switched on.
  static LoadableBars? loadedBar(GymProfileModel gym, String typeId) => gym
      .loadableBars
      .where((bar) => bar.typeId == typeId && bar.isActive)
      .firstOrNull;

  /// The bars switched on for exercises naming [typeId], lightest first:
  /// what the plate calculator offers to choose between.
  static List<BarBaseWeight> barChoices(GymProfileModel gym, String typeId) {
    final bar = loadedBar(gym, typeId);
    if (bar == null) return const [];
    return _stableSorted(
      [
        for (final weight in bar.baseWeights)
          if (weight.isActive) weight,
      ],
      (a, b) => _kilograms(
        a.baseWeight,
        a.unit,
      ).compareTo(_kilograms(b.baseWeight, b.unit)),
    );
  }

  /// [gym] loading bar [baseWeightId] under exercises naming [typeId].
  static GymProfileModel choosingBar(
    GymProfileModel gym,
    String baseWeightId, {
    required String typeId,
  }) {
    final bar = loadedBar(gym, typeId);
    if (bar == null) return gym;
    return updatingItem(gym, GymEquipmentList.loadableBars, bar.id, (data) {
      return {...data, GymEquipmentKeys.chosenBaseWeightId: baseWeightId};
    });
  }

  /// Every plate weight the gym lists, in [unit], heaviest first, with
  /// whether any plate of it is on. Only plates labelled in [unit] when there
  /// are any, the rule the weight keyboard loads by.
  static List<PlateChoice> plateChoices(
    GymProfileModel gym,
    ExerciseWeightUnit unit,
  ) {
    final labelled = _hasPlatesIn(gym, unit);
    final byWeight = <double, bool>{};
    for (final item in gym.freeWeights) {
      if (!item.isActive || !item.isPlates) continue;
      for (final plate in item.range) {
        if (labelled && plate.unit != unit) continue;
        final weight = _plateWeight(plate, unit);
        byWeight[weight] = (byWeight[weight] ?? false) || plate.isActive;
      }
    }
    return [
      for (final MapEntry(key: weight, value: isOn) in byWeight.entries)
        (weight: weight, isOn: isOn),
    ]..sort((a, b) => b.weight.compareTo(a.weight));
  }

  /// [gym] with every plate of [weight] (in [unit]) switched on or off,
  /// iron and bumper alike.
  static GymProfileModel settingPlate(
    GymProfileModel gym,
    double weight,
    ExerciseWeightUnit unit, {
    required bool isOn,
  }) {
    final labelled = _hasPlatesIn(gym, unit);
    return withItems(gym, GymEquipmentList.freeWeights, [
      for (final item in gym.freeWeights)
        if (!item.isActive || !item.isPlates)
          item
        else
          FreeWeights.fromFirestore({
            ...item.toFirestore(),
            GymEquipmentKeys.range: [
              for (final plate in item.range)
                if ((!labelled || plate.unit == unit) &&
                    (_plateWeight(plate, unit) - weight).abs() < 0.001)
                  {...plate.toFirestore(), GymEquipmentKeys.isActive: isOn}
                else
                  plate.toFirestore(),
            ],
          }),
    ]);
  }

  /// [current] with [edited]'s bar choices and plates, and nothing else of
  /// it: what the plate calculator changed, laid onto the gym as it now is.
  static GymProfileModel takingLoading(
    GymProfileModel current,
    GymProfileModel edited,
  ) {
    final bars = {for (final bar in edited.loadableBars) bar.id: bar};
    final plates = {for (final item in edited.freeWeights) item.id: item};
    return _with(current, {
      GymProfileModelKeys.loadableBars: [
        for (final bar in current.loadableBars)
          if (bars[bar.id] case final chosen?)
            {
              ...bar.toFirestore()..remove(GymEquipmentKeys.chosenBaseWeightId),
              GymEquipmentKeys.chosenBaseWeightId: ?chosen.chosenBaseWeightId,
            }
          else
            bar.toFirestore(),
      ],
      GymProfileModelKeys.freeWeights: [
        for (final item in current.freeWeights)
          if (item.isPlates && plates[item.id] != null)
            {
              ...item.toFirestore(),
              GymEquipmentKeys.range: plates[item.id]!
                  .toFirestore()[GymEquipmentKeys.range],
            }
          else
            item.toFirestore(),
      ],
    });
  }

  static bool _hasPlatesIn(GymProfileModel gym, ExerciseWeightUnit unit) =>
      gym.freeWeights.any(
        (item) =>
            item.isActive &&
            item.isPlates &&
            item.range.any((plate) => plate.unit == unit),
      );

  static double _kilograms(double value, ExerciseWeightUnit unit) =>
      unit == ExerciseWeightUnit.pounds ? value / _poundsPerKilogram : value;

  /// [plate]'s weight in [unit], to the gram.
  static double _plateWeight(
    FreeWeightsAvailable plate,
    ExerciseWeightUnit unit,
  ) {
    final kilograms = _kilograms(plate.availableWeights, plate.unit);
    final value = unit == ExerciseWeightUnit.pounds
        ? kilograms * _poundsPerKilogram
        : kilograms;
    return (value * 1000).roundToDouble() / 1000;
  }
}
