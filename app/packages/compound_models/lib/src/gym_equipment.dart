import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/gym_profile_model.dart';
import 'package:compound_models/src/training_enums.dart';

/// Field names of a gym's equipment items, exactly as Swift spells them:
/// the property names, which is the wire format these items have always
/// had. Each `…Fields` list is every field one kind of item writes.
abstract final class GymEquipmentKeys {
  /// `id`.
  static const id = 'id';

  /// `typeId`.
  static const typeId = 'typeId';

  /// `name`.
  static const name = 'name';

  /// `imageName`.
  static const imageName = 'imageName';

  /// `description`.
  static const description = 'description';

  /// `isActive`.
  static const isActive = 'isActive';

  /// `needsColour`.
  static const needsColour = 'needsColour';

  /// `isPlates`.
  static const isPlates = 'isPlates';

  /// `range`.
  static const range = 'range';

  /// `defaultBaseWeightId`.
  static const defaultBaseWeightId = 'defaultBaseWeightId';

  /// `chosenBaseWeightId`.
  static const chosenBaseWeightId = 'chosenBaseWeightId';

  /// `baseWeights`.
  static const baseWeights = 'baseWeights';

  /// `collarWeight`.
  static const collarWeight = 'collarWeight';

  /// `baseWeight`.
  static const baseWeight = 'baseWeight';

  /// `unit`.
  static const unit = 'unit';

  /// `sleeves`.
  static const sleeves = 'sleeves';

  /// `excludesBaseFromLoad`.
  static const excludesBaseFromLoad = 'excludesBaseFromLoad';

  /// `defaultRangeId`.
  static const defaultRangeId = 'defaultRangeId';

  /// `ranges`.
  static const ranges = 'ranges';

  /// `plateColour`.
  static const plateColour = 'plateColour';

  /// `availableWeights`.
  static const availableWeights = 'availableWeights';

  /// `count`.
  static const count = 'count';

  /// `bandColour`.
  static const bandColour = 'bandColour';

  /// `availableResistance`.
  static const availableResistance = 'availableResistance';

  /// `minWeight`.
  static const minWeight = 'minWeight';

  /// `maxWeight`.
  static const maxWeight = 'maxWeight';

  /// `increment`.
  static const increment = 'increment';

  /// `addOns`.
  static const addOns = 'addOns';

  /// `weights`.
  static const weights = 'weights';

  static const List<String> _item = [
    id,
    typeId,
    name,
    imageName,
    description,
    isActive,
  ];

  /// A [FreeWeights]' fields.
  static const List<String> freeWeightsFields = [
    ..._item,
    needsColour,
    isPlates,
    range,
  ];

  /// A [BodyWeights]' or [Bands]' fields.
  static const List<String> rangedFields = [..._item, range];

  /// A [LoadableBars]' fields.
  static const List<String> loadableBarsFields = [
    ..._item,
    defaultBaseWeightId,
    chosenBaseWeightId,
    baseWeights,
    collarWeight,
  ];

  /// A [FixedWeightBars]' fields.
  static const List<String> fixedWeightBarsFields = [
    ..._item,
    defaultBaseWeightId,
    baseWeights,
  ];

  /// A [PlainEquipment]'s fields.
  static const List<String> plainFields = _item;

  /// A [LoadableAccessoryEquipment]'s fields.
  static const List<String> loadableAccessoryFields = [
    ..._item,
    baseWeight,
    unit,
  ];

  /// A [StackMachine]'s fields.
  static const List<String> stackMachineFields = [
    ..._item,
    defaultRangeId,
    ranges,
  ];

  /// A [PlateLoadedMachine]'s fields.
  static const List<String> plateLoadedMachineFields = [
    ..._item,
    baseWeight,
    unit,
    sleeves,
    excludesBaseFromLoad,
  ];
}

// The decoding every item and entry shares, as Swift's hand-written
// decoders do it: `id` and `name` required, `typeId` falling back to the
// id (items saved before duplicates had their own type), `isActive` to off,
// and a missing `unit` to kilograms. A field of the wrong type, or an
// unknown unit, fails the item, which drops it from its lossy list.

String _id(Map<String, Object?> data) => data[GymEquipmentKeys.id]! as String;

String _name(Map<String, Object?> data) =>
    data[GymEquipmentKeys.name]! as String;

String _typeId(Map<String, Object?> data) =>
    data[GymEquipmentKeys.typeId] as String? ?? _id(data);

String? _imageName(Map<String, Object?> data) =>
    data[GymEquipmentKeys.imageName] as String?;

String? _description(Map<String, Object?> data) =>
    data[GymEquipmentKeys.description] as String?;

bool _isActive(Map<String, Object?> data) =>
    data[GymEquipmentKeys.isActive] as bool? ?? false;

ExerciseWeightUnit _unit(Map<String, Object?> data) =>
    switch (data[GymEquipmentKeys.unit]) {
      null => ExerciseWeightUnit.kilograms,
      final Object raw => enumFromValue(
        ExerciseWeightUnit.values,
        raw as String,
      ),
    };

List<T> _entries<T>(
  Object? stored,
  T Function(Map<String, Object?> data) decode,
) => lossyList(stored, (entry) => decode(readMap(entry))) ?? const [];

/// The catalogue type an item is, and the fields every item has.
abstract interface class GymEquipmentItem {
  /// This item in this gym, unique within its list.
  String get id;

  /// The catalogue type, which is what exercises name.
  String get typeId;

  /// Whether the gym has it.
  bool get isActive;

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore();
}

/// Dumbbells, kettlebells, plates and the like (Swift `FreeWeights`).
class const FreeWeights({
  /// This item in this gym.
  @override required final String id,

  /// The catalogue type.
  @override required final String typeId,

  /// The item's name.
  required final String name,

  /// Whether each weight needs a colour.
  required final bool needsColour,

  /// Plates for a bar or a plate-loaded machine.
  required final bool isPlates,

  /// The weights the gym has.
  required final List<FreeWeightsAvailable> range,

  /// Whether the gym has it.
  @override required final bool isActive,

  /// Its picture.
  final String? imageName,

  /// How it is described.
  final String? description,
}) implements GymEquipmentItem {
  /// Creates a [FreeWeights].
  this;

  /// Decodes as Swift does. Before `isPlates`, plates were known by an id
  /// ending in `plates`.
  factory fromFirestore(Map<String, Object?> data) => FreeWeights(
    id: _id(data),
    typeId: _typeId(data),
    name: _name(data),
    imageName: _imageName(data),
    description: _description(data),
    needsColour: data[GymEquipmentKeys.needsColour] as bool? ?? false,
    isPlates:
        data[GymEquipmentKeys.isPlates] as bool? ??
        _id(data).endsWith('plates'),
    range: _entries(
      data[GymEquipmentKeys.range],
      FreeWeightsAvailable.fromFirestore,
    ),
    isActive: _isActive(data),
  );

  @override
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.typeId: typeId,
    GymEquipmentKeys.name: name,
    GymEquipmentKeys.imageName: ?imageName,
    GymEquipmentKeys.description: ?description,
    GymEquipmentKeys.needsColour: needsColour,
    GymEquipmentKeys.isPlates: isPlates,
    GymEquipmentKeys.range: [for (final weight in range) weight.toFirestore()],
    GymEquipmentKeys.isActive: isActive,
  };
}

/// One weight of a [FreeWeights] (Swift `FreeWeightsAvailable`).
class const FreeWeightsAvailable({
  /// The entry's id.
  required final String id,

  /// The weight.
  required final double availableWeights,

  /// Its unit.
  required final ExerciseWeightUnit unit,

  /// Whether the gym has it.
  required final bool isActive,

  /// The plate's colour, as a hex string.
  final String? plateColour,

  /// How many the gym has; null is as many as a load needs.
  final int? count,
}) {
  /// Creates a [FreeWeightsAvailable].
  this;

  /// Decodes as Swift does: the weight is required.
  factory fromFirestore(Map<String, Object?> data) => FreeWeightsAvailable(
    id: _id(data),
    plateColour: data[GymEquipmentKeys.plateColour] as String?,
    availableWeights: readDouble(data[GymEquipmentKeys.availableWeights]),
    unit: _unit(data),
    isActive: _isActive(data),
    count: readOptionalInt(data[GymEquipmentKeys.count]),
  );

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.plateColour: ?plateColour,
    GymEquipmentKeys.availableWeights: availableWeights,
    GymEquipmentKeys.unit: unit.value,
    GymEquipmentKeys.isActive: isActive,
    GymEquipmentKeys.count: ?count,
  };
}

/// Weight vests, belts and the like that add to body weight (Swift
/// `BodyWeights`).
class const BodyWeights({
  /// This item in this gym.
  @override required final String id,

  /// The catalogue type.
  @override required final String typeId,

  /// The item's name.
  required final String name,

  /// The weights the gym has.
  required final List<BodyWeightsAvailable> range,

  /// Whether the gym has it.
  @override required final bool isActive,

  /// Its picture.
  final String? imageName,

  /// How it is described.
  final String? description,
}) implements GymEquipmentItem {
  /// Creates a [BodyWeights].
  this;

  /// Decodes as Swift does.
  factory fromFirestore(Map<String, Object?> data) => BodyWeights(
    id: _id(data),
    typeId: _typeId(data),
    name: _name(data),
    imageName: _imageName(data),
    description: _description(data),
    range: _entries(
      data[GymEquipmentKeys.range],
      BodyWeightsAvailable.fromFirestore,
    ),
    isActive: _isActive(data),
  );

  @override
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.typeId: typeId,
    GymEquipmentKeys.name: name,
    GymEquipmentKeys.imageName: ?imageName,
    GymEquipmentKeys.description: ?description,
    GymEquipmentKeys.range: [for (final weight in range) weight.toFirestore()],
    GymEquipmentKeys.isActive: isActive,
  };
}

/// One weight of a [BodyWeights] (Swift `BodyWeightsAvailable`).
class const BodyWeightsAvailable({
  /// The entry's id.
  required final String id,

  /// The weight.
  required final double availableWeights,

  /// Its unit.
  required final ExerciseWeightUnit unit,

  /// Whether the gym has it.
  required final bool isActive,

  /// Its colour, as a hex string.
  final String? plateColour,
}) {
  /// Creates a [BodyWeightsAvailable].
  this;

  /// Decodes as Swift does: the weight is required.
  factory fromFirestore(Map<String, Object?> data) => BodyWeightsAvailable(
    id: _id(data),
    plateColour: data[GymEquipmentKeys.plateColour] as String?,
    availableWeights: readDouble(data[GymEquipmentKeys.availableWeights]),
    unit: _unit(data),
    isActive: _isActive(data),
  );

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.plateColour: ?plateColour,
    GymEquipmentKeys.availableWeights: availableWeights,
    GymEquipmentKeys.unit: unit.value,
    GymEquipmentKeys.isActive: isActive,
  };
}

/// Resistance bands (Swift `Bands`).
class const Bands({
  /// This item in this gym.
  @override required final String id,

  /// The catalogue type.
  @override required final String typeId,

  /// The item's name.
  required final String name,

  /// The bands the gym has.
  required final List<BandsAvailable> range,

  /// Whether the gym has it.
  @override required final bool isActive,

  /// Its picture.
  final String? imageName,

  /// How it is described.
  final String? description,
}) implements GymEquipmentItem {
  /// Creates a [Bands].
  this;

  /// Decodes as Swift does.
  factory fromFirestore(Map<String, Object?> data) => Bands(
    id: _id(data),
    typeId: _typeId(data),
    name: _name(data),
    imageName: _imageName(data),
    description: _description(data),
    range: _entries(data[GymEquipmentKeys.range], BandsAvailable.fromFirestore),
    isActive: _isActive(data),
  );

  @override
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.typeId: typeId,
    GymEquipmentKeys.name: name,
    GymEquipmentKeys.imageName: ?imageName,
    GymEquipmentKeys.description: ?description,
    GymEquipmentKeys.range: [for (final band in range) band.toFirestore()],
    GymEquipmentKeys.isActive: isActive,
  };
}

/// One band of a [Bands] (Swift `BandsAvailable`).
class const BandsAvailable({
  /// The entry's id.
  required final String id,

  /// The band's name.
  required final String name,

  /// Its colour, as a hex string; empty when none was saved.
  required final String bandColour,

  /// Its resistance.
  required final double availableResistance,

  /// Its unit.
  required final ExerciseWeightUnit unit,

  /// Whether the gym has it.
  required final bool isActive,
}) {
  /// Creates a [BandsAvailable].
  this;

  /// Decodes as Swift does: the resistance is required.
  factory fromFirestore(Map<String, Object?> data) => BandsAvailable(
    id: _id(data),
    name: _name(data),
    bandColour: data[GymEquipmentKeys.bandColour] as String? ?? '',
    availableResistance: readDouble(data[GymEquipmentKeys.availableResistance]),
    unit: _unit(data),
    isActive: _isActive(data),
  );

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.name: name,
    GymEquipmentKeys.bandColour: bandColour,
    GymEquipmentKeys.availableResistance: availableResistance,
    GymEquipmentKeys.unit: unit.value,
    GymEquipmentKeys.isActive: isActive,
  };
}

/// Barbells and other bars plates load onto (Swift `LoadableBars`).
class const LoadableBars({
  /// This item in this gym.
  @override required final String id,

  /// The catalogue type.
  @override required final String typeId,

  /// The item's name.
  required final String name,

  /// The bar weights the gym has.
  required final List<BarBaseWeight> baseWeights,

  /// The collars' weight.
  required final double collarWeight,

  /// Whether the gym has it.
  @override required final bool isActive,

  /// Its picture.
  final String? imageName,

  /// How it is described.
  final String? description,

  /// The bar weight offered first.
  final String? defaultBaseWeightId,

  /// The bar weight the user picked.
  final String? chosenBaseWeightId,
}) implements GymEquipmentItem {
  /// Creates a [LoadableBars].
  this;

  /// Decodes as Swift does: a missing collar weighs nothing.
  factory fromFirestore(Map<String, Object?> data) => LoadableBars(
    id: _id(data),
    typeId: _typeId(data),
    name: _name(data),
    imageName: _imageName(data),
    description: _description(data),
    defaultBaseWeightId: data[GymEquipmentKeys.defaultBaseWeightId] as String?,
    chosenBaseWeightId: data[GymEquipmentKeys.chosenBaseWeightId] as String?,
    baseWeights: _entries(
      data[GymEquipmentKeys.baseWeights],
      BarBaseWeight.fromFirestore,
    ),
    collarWeight: readOptionalDouble(data[GymEquipmentKeys.collarWeight]) ?? 0,
    isActive: _isActive(data),
  );

  @override
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.typeId: typeId,
    GymEquipmentKeys.name: name,
    GymEquipmentKeys.imageName: ?imageName,
    GymEquipmentKeys.description: ?description,
    GymEquipmentKeys.defaultBaseWeightId: ?defaultBaseWeightId,
    GymEquipmentKeys.chosenBaseWeightId: ?chosenBaseWeightId,
    GymEquipmentKeys.baseWeights: [
      for (final weight in baseWeights) weight.toFirestore(),
    ],
    GymEquipmentKeys.collarWeight: collarWeight,
    GymEquipmentKeys.isActive: isActive,
  };
}

/// Bars that come at fixed weights, such as EZ bars (Swift
/// `FixedWeightBars`).
class const FixedWeightBars({
  /// This item in this gym.
  @override required final String id,

  /// The catalogue type.
  @override required final String typeId,

  /// The item's name.
  required final String name,

  /// The bars the gym has.
  required final List<BarBaseWeight> baseWeights,

  /// Whether the gym has it.
  @override required final bool isActive,

  /// Its picture.
  final String? imageName,

  /// How it is described.
  final String? description,

  /// The bar offered first.
  final String? defaultBaseWeightId,
}) implements GymEquipmentItem {
  /// Creates a [FixedWeightBars].
  this;

  /// Decodes as Swift does.
  factory fromFirestore(Map<String, Object?> data) => FixedWeightBars(
    id: _id(data),
    typeId: _typeId(data),
    name: _name(data),
    imageName: _imageName(data),
    description: _description(data),
    defaultBaseWeightId: data[GymEquipmentKeys.defaultBaseWeightId] as String?,
    baseWeights: _entries(
      data[GymEquipmentKeys.baseWeights],
      BarBaseWeight.fromFirestore,
    ),
    isActive: _isActive(data),
  );

  @override
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.typeId: typeId,
    GymEquipmentKeys.name: name,
    GymEquipmentKeys.imageName: ?imageName,
    GymEquipmentKeys.description: ?description,
    GymEquipmentKeys.defaultBaseWeightId: ?defaultBaseWeightId,
    GymEquipmentKeys.baseWeights: [
      for (final weight in baseWeights) weight.toFirestore(),
    ],
    GymEquipmentKeys.isActive: isActive,
  };
}

/// One weight of a bar (Swift `LoadableBarsBaseWeight` and
/// `FixedWeightBarsBaseWeight`, which are stored alike).
class const BarBaseWeight({
  /// The entry's id.
  required final String id,

  /// The bar's weight.
  required final double baseWeight,

  /// Its unit.
  required final ExerciseWeightUnit unit,

  /// Whether the gym has it.
  required final bool isActive,
}) {
  /// Creates a [BarBaseWeight].
  this;

  /// Decodes as Swift does: the weight is required.
  factory fromFirestore(Map<String, Object?> data) => BarBaseWeight(
    id: _id(data),
    baseWeight: readDouble(data[GymEquipmentKeys.baseWeight]),
    unit: _unit(data),
    isActive: _isActive(data),
  );

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.baseWeight: baseWeight,
    GymEquipmentKeys.unit: unit.value,
    GymEquipmentKeys.isActive: isActive,
  };
}

/// Equipment with nothing to weigh: benches and racks (Swift
/// `SupportEquipment`) and accessories such as an ab wheel (Swift
/// `AccessoryEquipment`), which are stored alike.
class const PlainEquipment({
  /// This item in this gym.
  @override required final String id,

  /// The catalogue type.
  @override required final String typeId,

  /// The item's name.
  required final String name,

  /// Whether the gym has it.
  @override required final bool isActive,

  /// Its picture.
  final String? imageName,

  /// How it is described.
  final String? description,
}) implements GymEquipmentItem {
  /// Creates a [PlainEquipment].
  this;

  /// Decodes as Swift does.
  factory fromFirestore(Map<String, Object?> data) => PlainEquipment(
    id: _id(data),
    typeId: _typeId(data),
    name: _name(data),
    imageName: _imageName(data),
    description: _description(data),
    isActive: _isActive(data),
  );

  @override
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.typeId: typeId,
    GymEquipmentKeys.name: name,
    GymEquipmentKeys.imageName: ?imageName,
    GymEquipmentKeys.description: ?description,
    GymEquipmentKeys.isActive: isActive,
  };
}

/// An accessory that takes plates, such as a landmine (Swift
/// `LoadableAccessoryEquipment`).
class const LoadableAccessoryEquipment({
  /// This item in this gym.
  @override required final String id,

  /// The catalogue type.
  @override required final String typeId,

  /// The item's name.
  required final String name,

  /// Its own weight.
  required final double baseWeight,

  /// Its unit.
  required final ExerciseWeightUnit unit,

  /// Whether the gym has it.
  @override required final bool isActive,

  /// Its picture.
  final String? imageName,

  /// How it is described.
  final String? description,
}) implements GymEquipmentItem {
  /// Creates a [LoadableAccessoryEquipment].
  this;

  /// Decodes as Swift does: a missing weight is 0.
  factory fromFirestore(Map<String, Object?> data) =>
      LoadableAccessoryEquipment(
        id: _id(data),
        typeId: _typeId(data),
        name: _name(data),
        imageName: _imageName(data),
        description: _description(data),
        baseWeight: readOptionalDouble(data[GymEquipmentKeys.baseWeight]) ?? 0,
        unit: _unit(data),
        isActive: _isActive(data),
      );

  @override
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.typeId: typeId,
    GymEquipmentKeys.name: name,
    GymEquipmentKeys.imageName: ?imageName,
    GymEquipmentKeys.description: ?description,
    GymEquipmentKeys.baseWeight: baseWeight,
    GymEquipmentKeys.unit: unit.value,
    GymEquipmentKeys.isActive: isActive,
  };
}

/// A machine loaded by a pinned weight stack: a cable machine (Swift
/// `CableMachine`) or a pin-loaded one (Swift `PinLoadedMachine`), which
/// are stored alike.
class const StackMachine({
  /// This item in this gym.
  @override required final String id,

  /// The catalogue type.
  @override required final String typeId,

  /// The item's name.
  required final String name,

  /// Its weight stacks.
  required final List<WeightStack> ranges,

  /// Whether the gym has it.
  @override required final bool isActive,

  /// Its picture.
  final String? imageName,

  /// How it is described.
  final String? description,

  /// The stack offered first.
  final String? defaultRangeId,
}) implements GymEquipmentItem {
  /// Creates a [StackMachine].
  this;

  /// Decodes as Swift does.
  factory fromFirestore(Map<String, Object?> data) => StackMachine(
    id: _id(data),
    typeId: _typeId(data),
    name: _name(data),
    imageName: _imageName(data),
    description: _description(data),
    defaultRangeId: data[GymEquipmentKeys.defaultRangeId] as String?,
    ranges: _entries(data[GymEquipmentKeys.ranges], WeightStack.fromFirestore),
    isActive: _isActive(data),
  );

  @override
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.typeId: typeId,
    GymEquipmentKeys.name: name,
    GymEquipmentKeys.imageName: ?imageName,
    GymEquipmentKeys.description: ?description,
    GymEquipmentKeys.defaultRangeId: ?defaultRangeId,
    GymEquipmentKeys.ranges: [for (final stack in ranges) stack.toFirestore()],
    GymEquipmentKeys.isActive: isActive,
  };
}

/// A machine's weight stack (Swift `WeightStack`).
class const WeightStack({
  /// The stack's id.
  required final String id,

  /// Its name.
  required final String name,

  /// The lightest pin position.
  required final double minWeight,

  /// The heaviest pin position.
  required final double maxWeight,

  /// The step between pin positions.
  required final double increment,

  /// Its unit.
  required final ExerciseWeightUnit unit,

  /// Whether the gym has it.
  required final bool isActive,

  /// The add-on weights that sit on top of it.
  final List<double> addOns = const [],

  /// Its exact pin positions, when they are not even steps.
  final List<double>? weights,
}) {
  /// Creates a [WeightStack].
  this;

  /// Decodes as Swift does: the three weights are required, and an
  /// unreadable `addOns` or `weights` reads as absent.
  factory fromFirestore(Map<String, Object?> data) => WeightStack(
    id: _id(data),
    name: _name(data),
    minWeight: readDouble(data[GymEquipmentKeys.minWeight]),
    maxWeight: readDouble(data[GymEquipmentKeys.maxWeight]),
    increment: readDouble(data[GymEquipmentKeys.increment]),
    unit: _unit(data),
    isActive: _isActive(data),
    addOns: _lenientDoubles(data[GymEquipmentKeys.addOns]) ?? const [],
    weights: _lenientDoubles(data[GymEquipmentKeys.weights]),
  );

  static List<double>? _lenientDoubles(Object? value) =>
      value is List && value.every((weight) => weight is num)
      ? [for (final weight in value) (weight as num).toDouble()]
      : null;

  /// The Firestore-shaped map Swift writes.
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.name: name,
    GymEquipmentKeys.minWeight: minWeight,
    GymEquipmentKeys.maxWeight: maxWeight,
    GymEquipmentKeys.increment: increment,
    GymEquipmentKeys.unit: unit.value,
    GymEquipmentKeys.isActive: isActive,
    GymEquipmentKeys.addOns: addOns,
    GymEquipmentKeys.weights: ?weights,
  };
}

/// A machine loaded with plates (Swift `PlateLoadedMachine`).
class const PlateLoadedMachine({
  /// This item in this gym.
  @override required final String id,

  /// The catalogue type.
  @override required final String typeId,

  /// The item's name.
  required final String name,

  /// The machine's own weight.
  required final double baseWeight,

  /// Its unit.
  required final ExerciseWeightUnit unit,

  /// How many sleeves take plates: 1 or 2.
  required final int sleeves,

  /// Whether a set's weight is the plates alone, without [baseWeight].
  required final bool excludesBaseFromLoad,

  /// Whether the gym has it.
  @override required final bool isActive,

  /// Its picture.
  final String? imageName,

  /// How it is described.
  final String? description,
}) implements GymEquipmentItem {
  /// Creates a [PlateLoadedMachine].
  this;

  /// Decodes as Swift does: a missing weight is 0, a machine saved before
  /// sleeves takes the catalogue's count for its type or else 2, any count
  /// is clamped to 1 or 2, and a missing `excludesBaseFromLoad` is on.
  factory fromFirestore(Map<String, Object?> data) {
    final typeId = _typeId(data);
    final sleeves =
        readOptionalInt(data[GymEquipmentKeys.sleeves]) ??
        GymEquipmentCatalogue.instance.plateLoadedMachines
            .where((machine) => machine.id == typeId)
            .firstOrNull
            ?.sleeves ??
        2;
    return PlateLoadedMachine(
      id: _id(data),
      typeId: typeId,
      name: _name(data),
      imageName: _imageName(data),
      description: _description(data),
      baseWeight: readOptionalDouble(data[GymEquipmentKeys.baseWeight]) ?? 0,
      unit: _unit(data),
      sleeves: sleeves.clamp(1, 2),
      excludesBaseFromLoad:
          data[GymEquipmentKeys.excludesBaseFromLoad] as bool? ?? true,
      isActive: _isActive(data),
    );
  }

  @override
  Map<String, Object?> toFirestore() => {
    GymEquipmentKeys.id: id,
    GymEquipmentKeys.typeId: typeId,
    GymEquipmentKeys.name: name,
    GymEquipmentKeys.imageName: ?imageName,
    GymEquipmentKeys.description: ?description,
    GymEquipmentKeys.baseWeight: baseWeight,
    GymEquipmentKeys.unit: unit.value,
    GymEquipmentKeys.sleeves: sleeves,
    GymEquipmentKeys.excludesBaseFromLoad: excludesBaseFromLoad,
    GymEquipmentKeys.isActive: isActive,
  };
}
