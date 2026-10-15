// Swift's reading rules, shared by both repositories.

import 'package:compound_models/compound_models.dart';

/// The body measurement fields `clearMeasurementFields` may remove: every
/// optional one. The keys an entry cannot decode without stay.
final Set<String> clearableMeasurementFields = {...BodyMeasurementEntryKeys.all}
  ..removeAll(const [
    BodyMeasurementEntryKeys.id,
    BodyMeasurementEntryKeys.authorId,
    BodyMeasurementEntryKeys.date,
    BodyMeasurementEntryKeys.source,
    BodyMeasurementEntryKeys.dateCreated,
  ]);

/// Throws an [ArgumentError] unless every one of [fields] is clearable.
void checkClearable(Set<String> fields) {
  final refused = fields.difference(clearableMeasurementFields);
  if (refused.isNotEmpty) {
    throw ArgumentError.value(refused, 'fields', 'Not clearable');
  }
}

/// The id of [uid]'s current goal document: [currentGoalId], or [uid] when
/// that is null or empty (an empty id is no document at all).
String currentGoalDocumentId(String uid, String? currentGoalId) =>
    currentGoalId == null || currentGoalId.isEmpty ? uid : currentGoalId;

/// [entries] without deleted ones, oldest first.
List<T> liveOldestFirst<T>(
  Iterable<T> entries, {
  required DateTime Function(T) date,
  required DateTime? Function(T) deletedAt,
}) => [
  for (final entry in entries)
    if (deletedAt(entry) == null) entry,
]..sort((a, b) => date(a).compareTo(date(b)));
