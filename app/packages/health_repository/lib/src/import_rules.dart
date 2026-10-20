// The Apple Health import rules, ported from the Swift managers' private
// `healthKitEntry` and `healthKitMeal`. Pure: the repository reads and
// writes around them.

import 'package:compound_models/compound_models.dart';
import 'package:health_repository/src/days.dart';
import 'package:health_repository/src/health_platform.dart';

final _uuid = RegExp(
  r'^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$',
);

/// [id] upper case when it is a UUID, else null: `healthkit_uuid` must hold
/// one, or the entry would no longer decode on either app.
String? healthUuid(String id) {
  final upper = id.toUpperCase();
  return _uuid.hasMatch(upper) ? upper : null;
}

/// The day's Health steps entry as it should now read, or null when nothing
/// needs writing (`StepsManager.healthKitEntry`). [dayEntries] are the
/// user's live entries that day.
StepsModel? stepsEntryForDay({
  required String uid,
  required DateTime day,
  required List<StepsModel> dayEntries,
  required int total,
  required DateTime now,
}) {
  final existing = dayEntries
      .where((entry) => entry.source == StepsSource.healthkit)
      .firstOrNull;
  if (existing != null) {
    if (existing.number == total) return null;
    return StepsModel.fromFirestore({
      ...existing.toFirestore(),
      StepsModelKeys.number: total,
      StepsModelKeys.dateModified: now,
    });
  }
  // Nothing to add, or a count entered here that day is already as high.
  if (total <= 0 || dayEntries.any((entry) => entry.number >= total)) {
    return null;
  }
  // The id is derived from the day, so a run that cannot yet see the last
  // one's write, or another device importing the same day, overwrites
  // rather than duplicates.
  return StepsModel(
    id: 'healthkit-steps-${epochSeconds(day)}',
    authorId: uid,
    number: total,
    date: day,
    source: StepsSource.healthkit,
    dateCreated: now,
    dateModified: now,
  );
}

/// What the body import does to one day.
sealed class BodyDayChange;

/// Save this entry, merged.
class const SaveEntry(final BodyMeasurementEntry entry)
    implements BodyDayChange {
  /// Creates a [SaveEntry].
  this;
}

/// Every weigh-in that day was deleted from Health: clear these fields of
/// the day's Health entry, keeping anything added to it in the app. Swift
/// merges the nils, which never reach Firestore (`swift-findings.md`).
class const ClearEntry(final String entryId) implements BodyDayChange {
  /// Creates a [ClearEntry].
  this;

  /// The fields cleared, as Swift sets them to nil.
  static const Set<String> fields = {
    BodyMeasurementEntryKeys.weightKg,
    BodyMeasurementEntryKeys.bodyFatPercentage,
    BodyMeasurementEntryKeys.healthKitUuid,
  };
}

/// The change to the day's Health body entry, or null when nothing needs
/// writing (`BodyMeasurementsManager.healthKitEntry`): the day's lowest
/// weigh-in, [weight], with its latest body fat reading, [bodyFat].
BodyDayChange? bodyChangeForDay({
  required String uid,
  required DateTime day,
  required List<BodyMeasurementEntry> dayEntries,
  required HealthSample? weight,
  required HealthSample? bodyFat,
}) {
  final existing = dayEntries
      .where((entry) => entry.source == WeightSource.healthkit)
      .firstOrNull;
  if (weight == null) {
    if (existing == null || existing.weightKg == null) return null;
    return ClearEntry(existing.id);
  }
  // A weigh-in logged here that day already reads as low or lower.
  if (existing == null &&
      dayEntries.any(
        (entry) => (entry.weightKg ?? double.infinity) <= weight.value,
      )) {
    return null;
  }
  final data =
      (existing ??
              BodyMeasurementEntry(
                id: 'healthkit-$uid-${epochSeconds(day)}',
                authorId: uid,
                date: weight.date,
                source: WeightSource.healthkit,
                dateCreated: weight.date,
              ))
          .toFirestore();
  final uuid = healthUuid(weight.uuid);
  // Same reading as last time: leave the weight alone, which keeps a weight
  // the person cleared here from coming back.
  if (existing == null || existing.healthKitUuid != uuid) {
    data
      ..[BodyMeasurementEntryKeys.weightKg] = weight.value
      ..[BodyMeasurementEntryKeys.date] = weight.date
      ..[BodyMeasurementEntryKeys.healthKitUuid] = uuid;
  }
  if (bodyFat != null) {
    data[BodyMeasurementEntryKeys.bodyFatPercentage] = bodyFat.value;
  }
  final entry = BodyMeasurementEntry.fromFirestore(data);
  if (existing != null &&
      entry.weightKg == existing.weightKg &&
      entry.bodyFatPercentage == existing.bodyFatPercentage &&
      entry.healthKitUuid == existing.healthKitUuid &&
      entry.date.isAtSameMomentAs(existing.date)) {
    return null;
  }
  return SaveEntry(entry);
}

/// [samples] by day, keeping the one [better] prefers over the rest; the
/// first wins a tie, as Swift's `min(by:)` and `max(by:)` do.
Map<DateTime, HealthSample> bestPerDay(
  Iterable<HealthSample> samples,
  bool Function(HealthSample candidate, HealthSample kept) better,
) {
  final best = <DateTime, HealthSample>{};
  for (final sample in samples) {
    final day = startOfDay(sample.date);
    final kept = best[day];
    if (kept == null || better(sample, kept)) best[day] = sample;
  }
  return best;
}

/// The day's Health import meal (`MealLogManager.healthKitMeal`): one
/// quick-add item carrying the day's totals. It resolves to nothing in the
/// food library, so the daily breakdown skips it while the totals, and the
/// expenditure estimate, count it.
MealLogModel healthMeal({
  required String uid,
  required DateTime day,
  required Map<NutrientKey, double> nutrients,
}) {
  final id = MealLogModel.healthKitMealId(dayKeyOf(day));
  return MealLogModel(
    mealId: id,
    authorId: uid,
    dayKey: dayKeyOf(day),
    date: day,
    items: [
      MealItemModel(
        itemId: id,
        sourceType: MealItemSourceType.quickAdd,
        sourceId: id,
        displayName: 'Apple Health',
        amount: 1,
        unit: 'serving',
        nutrients: NutrientMap(nutrients),
      ),
    ],
  );
}

/// Every nutrient in [meal], summed across its items (Swift
/// `totalNutrients`).
Map<NutrientKey, double> mealTotals(MealLogModel meal) {
  final totals = <NutrientKey, double>{};
  for (final item in meal.items) {
    for (final MapEntry(:key, :value) in item.nutrients.values.entries) {
      totals[key] = (totals[key] ?? 0) + value;
    }
  }
  return totals;
}
