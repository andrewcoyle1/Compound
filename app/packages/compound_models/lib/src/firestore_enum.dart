/// An enum stored in Firestore by a raw string, spelled exactly as the
/// Swift app's raw value.
abstract interface class FirestoreEnum {
  /// The stored string.
  String get value;
}

/// The case of [values] stored as [raw].
///
/// Throws a [FormatException] for an unknown value, as Swift's decoder
/// fails on one.
T enumFromValue<T extends FirestoreEnum>(List<T> values, String raw) {
  for (final candidate in values) {
    if (candidate.value == raw) return candidate;
  }
  throw FormatException('Unknown $T value', raw);
}

/// The case of [values] stored as [raw], or null for an unknown or
/// non-string value: for fields Swift reads with `try?`.
T? enumFromValueOrNull<T extends FirestoreEnum>(List<T> values, Object? raw) {
  for (final candidate in values) {
    if (candidate.value == raw) return candidate;
  }
  return null;
}
