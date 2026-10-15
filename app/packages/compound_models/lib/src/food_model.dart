import 'package:compound_models/src/firestore_enum.dart';
import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/nutrient_map.dart';
import 'package:compound_models/src/nutrition_enums.dart';

/// Field names of a [FoodModel], exactly as the Swift `CodingKeys` spell
/// them.
abstract final class FoodModelKeys {
  /// `ingredient_id`, the food's id.
  static const ingredientId = 'ingredient_id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `name`.
  static const name = 'name';

  /// `brand_name`.
  static const brandName = 'brand_name';

  /// `description`.
  static const description = 'description';

  /// `measurement_method`.
  static const measurementMethod = 'measurement_method';

  /// `nutrients`.
  static const nutrients = 'nutrients';

  /// `barcode`.
  static const barcode = 'barcode';

  /// `serving_weight`.
  static const servingWeight = 'serving_weight';

  /// `portion_size`.
  static const portionSize = 'portion_size';

  /// `portion_name`.
  static const portionName = 'portion_name';

  /// `portion_weight`.
  static const portionWeight = 'portion_weight';

  /// `weight_portion_size`.
  static const weightPortionSize = 'weight_portion_size';

  /// `weight_portion_name`.
  static const weightPortionName = 'weight_portion_name';

  /// `portion_volume`.
  static const portionVolume = 'portion_volume';

  /// `volume_portion_size`.
  static const volumePortionSize = 'volume_portion_size';

  /// `volume_portion_name`.
  static const volumePortionName = 'volume_portion_name';

  /// `image_url`.
  static const imageUrl = 'image_url';

  /// `date_created`.
  static const dateCreated = 'date_created';

  /// `date_modified`.
  static const dateModified = 'date_modified';

  /// `click_count`.
  static const clickCount = 'click_count';

  /// `bookmark_count`.
  static const bookmarkCount = 'bookmark_count';

  /// `favourite_count`.
  static const favouriteCount = 'favourite_count';

  /// Every field, in declaration order.
  static const List<String> all = [
    ingredientId,
    authorId,
    name,
    brandName,
    description,
    measurementMethod,
    nutrients,
    barcode,
    servingWeight,
    portionSize,
    portionName,
    portionWeight,
    weightPortionSize,
    weightPortionName,
    portionVolume,
    volumePortionSize,
    volumePortionName,
    imageUrl,
    dateCreated,
    dateModified,
    clickCount,
    bookmarkCount,
    favouriteCount,
  ];
}

/// A food in the user's library, at `users/{uid}/foods/{ingredientId}`
/// (Swift `FoodModel`). Nutrients are per 100 g, or per 100 ml for a food
/// measured by volume.
///
/// A portion is "`total` for `count` of `name`": `servingWeight` for
/// `portionSize` of `portionName`, `portionWeight` for `weightPortionSize`
/// of `weightPortionName`, and `portionVolume` for `volumePortionSize` of
/// `volumePortionName`.
class const FoodModel({
  /// The food's id, stored as `ingredient_id`.
  required final String ingredientId,

  /// Its name.
  required final String name,

  /// When it was made.
  required final DateTime dateCreated,

  /// When it was last changed.
  required final DateTime dateModified,

  /// Its owner's user id. The rules refuse a write without it.
  final String? authorId,

  /// Its brand.
  final String? brandName,

  /// How it is described.
  final String? description,

  /// Whether it is recorded by mass or by volume.
  final MeasurementMethod measurementMethod = MeasurementMethod.weight,

  /// Its nutrients, per 100 g or 100 ml.
  final NutrientMap nutrients = const NutrientMap(),

  /// Its barcode.
  final String? barcode,

  /// Grams in one serving.
  final double? servingWeight,

  /// How many [portionName] one serving is.
  final double? portionSize,

  /// The serving's unit name.
  final String? portionName,

  /// Grams in one mass portion.
  final double? portionWeight,

  /// How many [weightPortionName] one mass portion is.
  final double? weightPortionSize,

  /// The mass portion's unit name.
  final String? weightPortionName,

  /// Millilitres in one volume portion.
  final double? portionVolume,

  /// How many [volumePortionName] one volume portion is.
  final double? volumePortionSize,

  /// The volume portion's unit name.
  final String? volumePortionName,

  /// Its picture.
  final String? imageUrl,

  /// How often it has been opened.
  final int? clickCount,

  /// How often it has been bookmarked.
  final int? bookmarkCount,

  /// How often it has been made a favourite.
  final int? favouriteCount,
}) {
  /// Creates a [FoodModel].
  this;

  /// Decodes strictly, as Swift's synthesized decoder does: a null optional
  /// reads as absent, and the flat nutrient fields older builds wrote
  /// (`calories`, `fat_total`, …) are ignored. The nutrients decode as
  /// [NutrientMap.fromFirestore] does.
  factory fromFirestore(Map<String, Object?> data) => FoodModel(
    ingredientId: data[FoodModelKeys.ingredientId]! as String,
    authorId: data[FoodModelKeys.authorId] as String?,
    name: data[FoodModelKeys.name]! as String,
    brandName: data[FoodModelKeys.brandName] as String?,
    description: data[FoodModelKeys.description] as String?,
    measurementMethod: enumFromValue(
      MeasurementMethod.values,
      data[FoodModelKeys.measurementMethod]! as String,
    ),
    nutrients: NutrientMap.fromFirestore(
      readMap(data[FoodModelKeys.nutrients]),
    ),
    barcode: data[FoodModelKeys.barcode] as String?,
    servingWeight: readOptionalDouble(data[FoodModelKeys.servingWeight]),
    portionSize: readOptionalDouble(data[FoodModelKeys.portionSize]),
    portionName: data[FoodModelKeys.portionName] as String?,
    portionWeight: readOptionalDouble(data[FoodModelKeys.portionWeight]),
    weightPortionSize: readOptionalDouble(
      data[FoodModelKeys.weightPortionSize],
    ),
    weightPortionName: data[FoodModelKeys.weightPortionName] as String?,
    portionVolume: readOptionalDouble(data[FoodModelKeys.portionVolume]),
    volumePortionSize: readOptionalDouble(
      data[FoodModelKeys.volumePortionSize],
    ),
    volumePortionName: data[FoodModelKeys.volumePortionName] as String?,
    imageUrl: data[FoodModelKeys.imageUrl] as String?,
    dateCreated: data[FoodModelKeys.dateCreated]! as DateTime,
    dateModified: data[FoodModelKeys.dateModified]! as DateTime,
    clickCount: readOptionalInt(data[FoodModelKeys.clickCount]),
    bookmarkCount: readOptionalInt(data[FoodModelKeys.bookmarkCount]),
    favouriteCount: readOptionalInt(data[FoodModelKeys.favouriteCount]),
  );

  /// The Firestore-shaped map Swift writes, a null field left out.
  Map<String, Object?> toFirestore() => {
    FoodModelKeys.ingredientId: ingredientId,
    FoodModelKeys.authorId: ?authorId,
    FoodModelKeys.name: name,
    FoodModelKeys.brandName: ?brandName,
    FoodModelKeys.description: ?description,
    FoodModelKeys.measurementMethod: measurementMethod.value,
    FoodModelKeys.nutrients: nutrients.toFirestore(),
    FoodModelKeys.barcode: ?barcode,
    FoodModelKeys.servingWeight: ?servingWeight,
    FoodModelKeys.portionSize: ?portionSize,
    FoodModelKeys.portionName: ?portionName,
    FoodModelKeys.portionWeight: ?portionWeight,
    FoodModelKeys.weightPortionSize: ?weightPortionSize,
    FoodModelKeys.weightPortionName: ?weightPortionName,
    FoodModelKeys.portionVolume: ?portionVolume,
    FoodModelKeys.volumePortionSize: ?volumePortionSize,
    FoodModelKeys.volumePortionName: ?volumePortionName,
    FoodModelKeys.imageUrl: ?imageUrl,
    FoodModelKeys.dateCreated: dateCreated,
    FoodModelKeys.dateModified: dateModified,
    FoodModelKeys.clickCount: ?clickCount,
    FoodModelKeys.bookmarkCount: ?bookmarkCount,
    FoodModelKeys.favouriteCount: ?favouriteCount,
  };

  /// The units this food can be logged in besides grams or millilitres,
  /// from the portions it declares (Swift `FoodModel.servingUnits`).
  ///
  /// Only portions in the food's own base unit are offered, a portion named
  /// "g" or "ml" is skipped, and a repeated name keeps its first unit.
  List<ServingUnit> get servingUnits {
    final portions = switch (measurementMethod) {
      MeasurementMethod.weight => [
        ServingUnit._from(portionName, servingWeight, portionSize),
        ServingUnit._from(weightPortionName, portionWeight, weightPortionSize),
      ],
      MeasurementMethod.volume => [
        ServingUnit._from(volumePortionName, portionVolume, volumePortionSize),
      ],
    };
    final units = <ServingUnit>[];
    for (final unit in portions.nonNulls) {
      if (!units.any((existing) => existing.name == unit.name)) {
        units.add(unit);
      }
    }
    return units;
  }
}

/// A named household unit a food can be logged in, and how much of the
/// food's base unit one of it is (Swift `ServingUnit`). [grams] is
/// millilitres for a food measured by volume. Derived, never stored.
class const ServingUnit({
  /// The unit's name, such as "slice".
  required final String name,

  /// Grams (or millilitres) in one of it.
  required final double grams,
}) {
  /// Creates a [ServingUnit].
  this;

  /// One of a portion that is [total] for [count] of [name], or null when
  /// it has no usable name or total. A missing or unusable count is 1.
  static ServingUnit? _from(String? name, double? total, double? count) {
    final trimmed = name?.replaceAll(_edgeSpaces, '');
    if (trimmed == null ||
        trimmed.isEmpty ||
        const ['g', 'ml'].contains(trimmed.toLowerCase()) ||
        total == null ||
        !total.isFinite ||
        total <= 0) {
      return null;
    }
    final per = count != null && count.isFinite && count > 0 ? count : 1;
    return ServingUnit(name: trimmed, grams: total / per);
  }

  /// Swift's `.whitespaces`: spaces and tabs, but not line breaks.
  static final _edgeSpaces = RegExp(
    r'^[\p{Zs}\t]+|[\p{Zs}\t]+$',
    unicode: true,
  );
}
