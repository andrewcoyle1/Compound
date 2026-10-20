import 'package:compound_models/src/firestore_values.dart';
import 'package:compound_models/src/meal_item_model.dart';

/// Field names of `users/{uid}/meal_logs/{meal_id}`, exactly as the Swift
/// `CodingKeys` spell them.
///
/// Partial updates and queries take their field names only from here.
abstract final class MealLogModelKeys {
  /// `meal_id`.
  static const mealId = 'meal_id';

  /// `author_id`.
  static const authorId = 'author_id';

  /// `day_key`.
  static const dayKey = 'day_key';

  /// `date`.
  static const date = 'date';

  /// `items`.
  static const items = 'items';

  /// `notes`.
  static const notes = 'notes';

  /// Every field, in declaration order.
  static const List<String> all = [
    mealId,
    authorId,
    dayKey,
    date,
    items,
    notes,
  ];
}

/// A logged meal at `users/{uid}/meal_logs/{meal_id}` (Swift
/// `MealLogModel`).
class const MealLogModel({
  /// The meal's id, and the document id.
  required final String mealId,

  /// The user who logged it.
  required final String authorId,

  /// The day it belongs to, `yyyy-MM-dd` on the user's calendar.
  required final String dayKey,

  /// When it was eaten.
  required final DateTime date,

  /// What was eaten.
  required final List<MealItemModel> items,

  /// The user's notes.
  final String? notes,
}) {
  /// Creates a [MealLogModel].
  this;

  /// Decodes as Swift's synthesized decoder does, strictly: a missing field,
  /// a wrong type or an unreadable item throws. Unknown keys are ignored,
  /// and a null `notes` reads as absent.
  factory fromFirestore(Map<String, Object?> data) => MealLogModel(
    mealId: data[MealLogModelKeys.mealId]! as String,
    authorId: data[MealLogModelKeys.authorId]! as String,
    dayKey: data[MealLogModelKeys.dayKey]! as String,
    date: data[MealLogModelKeys.date]! as DateTime,
    items: [
      for (final item in data[MealLogModelKeys.items]! as List<Object?>)
        MealItemModel.fromFirestore(readMap(item)),
    ],
    notes: data[MealLogModelKeys.notes] as String?,
  );

  /// The id of the meal holding [dayKey]'s totals imported from Apple
  /// Health. Derived from the day, so every device writes the same document.
  static String healthKitMealId(String dayKey) => 'healthkit-nutrition-$dayKey';

  /// Whether this is a day's totals imported from Apple Health rather than
  /// a meal logged in Compound.
  bool get isHealthKitImport => mealId == healthKitMealId(dayKey);

  /// The Firestore-shaped map Swift writes: a null field is left out.
  Map<String, Object?> toFirestore() => {
    MealLogModelKeys.mealId: mealId,
    MealLogModelKeys.authorId: authorId,
    MealLogModelKeys.dayKey: dayKey,
    MealLogModelKeys.date: date,
    MealLogModelKeys.items: [for (final item in items) item.toFirestore()],
    MealLogModelKeys.notes: ?notes,
  };
}
