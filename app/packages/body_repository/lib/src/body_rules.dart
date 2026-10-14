// Swift's reading rules, shared by both repositories.

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
