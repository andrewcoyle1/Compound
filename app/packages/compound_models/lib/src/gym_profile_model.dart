import 'dart:convert';

import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/gym_equipment.dart';
import 'package:compound_models/src/gym_equipment_catalogue_json.dart';

/// Field names of a [GymProfileModel], exactly as the Swift `CodingKeys`
/// spell them.
abstract final class GymProfileModelKeys {
  /// `id`.
  static const id = 'id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `name`.
  static const name = 'name';

  /// `image_url`.
  static const imageUrl = 'image_url';

  /// `icon`.
  static const icon = 'icon';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `date_modified`.
  static const dateModified = 'date_modified';

  /// `deleted_at`.
  static const deletedAt = 'deleted_at';

  /// `free_weights`.
  static const freeWeights = 'free_weights';

  /// `loadable_bars`.
  static const loadableBars = 'loadable_bars';

  /// `fixed_weight_bars`.
  static const fixedWeightBars = 'fixed_weight_bars';

  /// `bands`.
  static const bands = 'bands';

  /// `body_weights`.
  static const bodyWeights = 'body_weights';

  /// `support_equipment`.
  static const supportEquipment = 'support_equipment';

  /// `accessory_equipment`.
  static const accessoryEquipment = 'accessory_equipment';

  /// `loadable_accessory_equipment`.
  static const loadableAccessoryEquipment = 'loadable_accessory_equipment';

  /// `cable_machines`.
  static const cableMachines = 'cable_machines';

  /// `plate_loaded_machines`.
  static const plateLoadedMachines = 'plate_loaded_machines';

  /// `pin_loaded_machines`.
  static const pinLoadedMachines = 'pin_loaded_machines';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    authorId,
    name,
    imageUrl,
    icon,
    dateCreated,
    dateModified,
    deletedAt,
    freeWeights,
    loadableBars,
    fixedWeightBars,
    bands,
    bodyWeights,
    supportEquipment,
    accessoryEquipment,
    loadableAccessoryEquipment,
    cableMachines,
    plateLoadedMachines,
    pinLoadedMachines,
  ];
}

/// A gym and the equipment it has, at `users/{uid}/gym_profiles/{id}`
/// (Swift `GymProfileModel`).
class const GymProfileModel({
  /// The profile's id.
  required final String id,

  /// The user.
  required final String authorId,

  /// The gym's name.
  required final String name,

  /// The SF Symbol it is shown with.
  required final String icon,

  /// When it was made.
  required final DateTime dateCreated,

  /// When it was last changed.
  required final DateTime dateModified,

  /// Its free weights.
  required final List<FreeWeights> freeWeights,

  /// Its bars that take plates.
  required final List<LoadableBars> loadableBars,

  /// Its fixed-weight bars.
  required final List<FixedWeightBars> fixedWeightBars,

  /// Its bands.
  required final List<Bands> bands,

  /// Its body-weight additions.
  required final List<BodyWeights> bodyWeights,

  /// Its benches, racks and stations.
  required final List<PlainEquipment> supportEquipment,

  /// Its accessories.
  required final List<PlainEquipment> accessoryEquipment,

  /// Its accessories that take plates.
  required final List<LoadableAccessoryEquipment> loadableAccessoryEquipment,

  /// Its cable machines.
  required final List<StackMachine> cableMachines,

  /// Its plate-loaded machines.
  required final List<PlateLoadedMachine> plateLoadedMachines,

  /// Its pin-loaded machines.
  required final List<StackMachine> pinLoadedMachines,

  /// Its picture.
  final String? imageUrl,

  /// When it was deleted.
  final DateTime? deletedAt,
}) {
  /// Creates a [GymProfileModel].
  this;

  /// Decodes as Swift does: only `id` and `author_id` are required, the
  /// name defaults to empty, the icon to `dumbbell` and a missing date to
  /// now. Each equipment list skips an item it cannot read and then gains,
  /// switched off, every catalogue item it lacks; a missing or unreadable
  /// list is the catalogue as it is ([GymEquipmentCatalogue]).
  factory fromFirestore(Map<String, Object?> data) {
    final catalogue = GymEquipmentCatalogue.instance;
    return GymProfileModel(
      id: data[GymProfileModelKeys.id]! as String,
      authorId: data[GymProfileModelKeys.authorId]! as String,
      name: data[GymProfileModelKeys.name] as String? ?? '',
      imageUrl: data[GymProfileModelKeys.imageUrl] as String?,
      icon: data[GymProfileModelKeys.icon] as String? ?? 'dumbbell',
      dateCreated:
          data[GymProfileModelKeys.dateCreated] as DateTime? ?? DateTime.now(),
      dateModified:
          data[GymProfileModelKeys.dateModified] as DateTime? ?? DateTime.now(),
      deletedAt: data[GymProfileModelKeys.deletedAt] as DateTime?,
      freeWeights: _merging(
        data[GymProfileModelKeys.freeWeights],
        catalogue.freeWeights,
        FreeWeights.fromFirestore,
      ),
      loadableBars: _merging(
        data[GymProfileModelKeys.loadableBars],
        catalogue.loadableBars,
        LoadableBars.fromFirestore,
      ),
      fixedWeightBars: _merging(
        data[GymProfileModelKeys.fixedWeightBars],
        catalogue.fixedWeightBars,
        FixedWeightBars.fromFirestore,
      ),
      bands: _merging(
        data[GymProfileModelKeys.bands],
        catalogue.bands,
        Bands.fromFirestore,
      ),
      bodyWeights: _merging(
        data[GymProfileModelKeys.bodyWeights],
        catalogue.bodyWeights,
        BodyWeights.fromFirestore,
      ),
      supportEquipment: _merging(
        data[GymProfileModelKeys.supportEquipment],
        catalogue.supportEquipment,
        PlainEquipment.fromFirestore,
      ),
      accessoryEquipment: _merging(
        data[GymProfileModelKeys.accessoryEquipment],
        catalogue.accessoryEquipment,
        PlainEquipment.fromFirestore,
      ),
      loadableAccessoryEquipment: _merging(
        data[GymProfileModelKeys.loadableAccessoryEquipment],
        catalogue.loadableAccessoryEquipment,
        LoadableAccessoryEquipment.fromFirestore,
      ),
      cableMachines: _merging(
        data[GymProfileModelKeys.cableMachines],
        catalogue.cableMachines,
        StackMachine.fromFirestore,
      ),
      plateLoadedMachines: _merging(
        data[GymProfileModelKeys.plateLoadedMachines],
        catalogue.plateLoadedMachines,
        PlateLoadedMachine.fromFirestore,
      ),
      pinLoadedMachines: _merging(
        data[GymProfileModelKeys.pinLoadedMachines],
        catalogue.pinLoadedMachines,
        StackMachine.fromFirestore,
      ),
    );
  }

  /// Swift's `mergingCatalogue`: the stored list, then every catalogue item
  /// it lacks, switched off.
  static List<T> _merging<T extends GymEquipmentItem>(
    Object? stored,
    List<T> catalogue,
    T Function(Map<String, Object?> data) decode,
  ) {
    final items = lossyList(stored, (item) => decode(readMap(item)));
    if (items == null) return catalogue;
    final ids = {for (final item in items) item.id};
    return [
      ...items,
      for (final item in catalogue)
        if (!ids.contains(item.id))
          decode({...item.toFirestore(), GymEquipmentKeys.isActive: false}),
    ];
  }

  /// The Firestore-shaped map Swift writes: every list, and a null field
  /// left out.
  Map<String, Object?> toFirestore() => {
    GymProfileModelKeys.id: id,
    GymProfileModelKeys.authorId: authorId,
    GymProfileModelKeys.name: name,
    GymProfileModelKeys.imageUrl: ?imageUrl,
    GymProfileModelKeys.icon: icon,
    GymProfileModelKeys.dateCreated: dateCreated,
    GymProfileModelKeys.dateModified: dateModified,
    GymProfileModelKeys.deletedAt: ?deletedAt,
    GymProfileModelKeys.freeWeights: _encode(freeWeights),
    GymProfileModelKeys.loadableBars: _encode(loadableBars),
    GymProfileModelKeys.fixedWeightBars: _encode(fixedWeightBars),
    GymProfileModelKeys.bands: _encode(bands),
    GymProfileModelKeys.bodyWeights: _encode(bodyWeights),
    GymProfileModelKeys.supportEquipment: _encode(supportEquipment),
    GymProfileModelKeys.accessoryEquipment: _encode(accessoryEquipment),
    GymProfileModelKeys.loadableAccessoryEquipment: _encode(
      loadableAccessoryEquipment,
    ),
    GymProfileModelKeys.cableMachines: _encode(cableMachines),
    GymProfileModelKeys.plateLoadedMachines: _encode(plateLoadedMachines),
    GymProfileModelKeys.pinLoadedMachines: _encode(pinLoadedMachines),
  };

  static List<Map<String, Object?>> _encode(List<GymEquipmentItem> items) => [
    for (final item in items) item.toFirestore(),
  ];
}

/// The equipment a new gym starts with: Swift's catalogue
/// (`GymProfileModel`'s defaults), which every stored profile gains on
/// decoding. Read from `contracts/firestore/gym_equipment_catalogue.json`,
/// recorded by the Swift contract tests, where each nested entry's id (random
/// per launch in Swift) is `<item id>_<n>`.
final class GymEquipmentCatalogue {
  new _(Map<String, Object?> lists)
    : freeWeights = _items(
        lists[GymProfileModelKeys.freeWeights],
        FreeWeights.fromFirestore,
      ),
      loadableBars = _items(
        lists[GymProfileModelKeys.loadableBars],
        LoadableBars.fromFirestore,
      ),
      fixedWeightBars = _items(
        lists[GymProfileModelKeys.fixedWeightBars],
        FixedWeightBars.fromFirestore,
      ),
      bands = _items(lists[GymProfileModelKeys.bands], Bands.fromFirestore),
      bodyWeights = _items(
        lists[GymProfileModelKeys.bodyWeights],
        BodyWeights.fromFirestore,
      ),
      supportEquipment = _items(
        lists[GymProfileModelKeys.supportEquipment],
        PlainEquipment.fromFirestore,
      ),
      accessoryEquipment = _items(
        lists[GymProfileModelKeys.accessoryEquipment],
        PlainEquipment.fromFirestore,
      ),
      loadableAccessoryEquipment = _items(
        lists[GymProfileModelKeys.loadableAccessoryEquipment],
        LoadableAccessoryEquipment.fromFirestore,
      ),
      cableMachines = _items(
        lists[GymProfileModelKeys.cableMachines],
        StackMachine.fromFirestore,
      ),
      plateLoadedMachines = _items(
        lists[GymProfileModelKeys.plateLoadedMachines],
        PlateLoadedMachine.fromFirestore,
      ),
      pinLoadedMachines = _items(
        lists[GymProfileModelKeys.pinLoadedMachines],
        StackMachine.fromFirestore,
      );

  /// The catalogue.
  static final instance = GymEquipmentCatalogue._(
    jsonDecode(gymEquipmentCatalogueJson) as Map<String, Object?>,
  );

  static List<T> _items<T>(
    Object? list,
    T Function(Map<String, Object?> data) decode,
  ) => List.unmodifiable([
    for (final item in list! as List<Object?>) decode(readMap(item)),
  ]);

  /// The free weights.
  final List<FreeWeights> freeWeights;

  /// The bars that take plates.
  final List<LoadableBars> loadableBars;

  /// The fixed-weight bars.
  final List<FixedWeightBars> fixedWeightBars;

  /// The bands.
  final List<Bands> bands;

  /// The body-weight additions.
  final List<BodyWeights> bodyWeights;

  /// The benches, racks and stations.
  final List<PlainEquipment> supportEquipment;

  /// The accessories.
  final List<PlainEquipment> accessoryEquipment;

  /// The accessories that take plates.
  final List<LoadableAccessoryEquipment> loadableAccessoryEquipment;

  /// The cable machines.
  final List<StackMachine> cableMachines;

  /// The plate-loaded machines.
  final List<PlateLoadedMachine> plateLoadedMachines;

  /// The pin-loaded machines.
  final List<StackMachine> pinLoadedMachines;
}
