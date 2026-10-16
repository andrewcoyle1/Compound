import 'package:compound_models/src/firestore_enum.dart';

/// Where a logged meal item came from (Swift `MealItemSourceType`).
enum MealItemSourceType implements FirestoreEnum {
  /// `ingredient`: a food from the library.
  ingredient('ingredient'),

  /// `recipe`.
  recipe('recipe'),

  /// `quick_add`: macros typed straight in, with no food behind them.
  quickAdd('quick_add');

  new(this.value);

  @override
  final String value;

  /// The case stored as [raw], which must be a string. A value this build
  /// does not know reads as [ingredient], as Swift's decoder falls back, so
  /// the rest of the meal stays readable.
  static MealItemSourceType fromFirestore(Object? raw) =>
      enumFromValueOrNull(values, raw! as String) ?? ingredient;
}

/// Which side of the timeline food times are shown on (Swift
/// `TimestampSide`).
enum TimestampSide implements FirestoreEnum {
  /// `left`.
  left('left'),

  /// `right`.
  right('right');

  new(this.value);

  @override
  final String value;
}

/// Whether a food is recorded by mass or by volume (Swift
/// `MeasurementMethod`).
enum MeasurementMethod implements FirestoreEnum {
  /// `weight`: amounts in grams.
  weight('weight'),

  /// `volume`: amounts in millilitres.
  volume('volume');

  new(this.value);

  @override
  final String value;
}
