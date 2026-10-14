/// The key that tags a Timestamp in contract fixtures, as in
/// `{r'$timestamp': '2026-01-02T03:04:05.123Z'}`.
const timestampTag = r'$timestamp';

/// Contract fixture JSON to a Firestore-shaped map: each tagged timestamp
/// becomes a UTC [DateTime].
Map<String, Object?> taggedJsonToFirestore(Map<String, Object?> json) =>
    json.map((key, value) => MapEntry(key, _fromTagged(value)));

Object? _fromTagged(Object? value) => switch (value) {
  {timestampTag: final String iso} when value.length == 1 => DateTime.parse(
    iso,
  ).toUtc(),
  final Map<String, Object?> map => taggedJsonToFirestore(map),
  final List<Object?> list => list.map(_fromTagged).toList(),
  _ => value,
};

/// A Firestore-shaped map to contract fixture JSON: each [DateTime] becomes
/// a tagged UTC timestamp to the millisecond, the contract's precision.
///
/// Throws an [ArgumentError] for a value that is neither JSON nor a
/// timestamp.
Map<String, Object?> firestoreToTaggedJson(Map<String, Object?> firestore) =>
    firestore.map((key, value) => MapEntry(key, _toTagged(value)));

Object? _toTagged(Object? value) => switch (value) {
  null || bool() || num() || String() => value,
  final DateTime date => {timestampTag: formatContractTimestamp(date)},
  final Map<String, Object?> map => firestoreToTaggedJson(map),
  final List<Object?> list => list.map(_toTagged).toList(),
  _ => throw ArgumentError.value(value, 'value', 'not a Firestore value'),
};

/// [date] in UTC, rounded to the millisecond, with exactly three
/// fractional digits.
String formatContractTimestamp(DateTime date) =>
    DateTime.fromMillisecondsSinceEpoch(
      (date.microsecondsSinceEpoch / 1000).round(),
      isUtc: true,
    ).toIso8601String();
