/// Parameter clean-up for each backend, following the Swift services'
/// rules so the two apps send the same values.
library;

/// Firebase's limit on event and parameter names.
const firebaseNameLength = 40;

/// Firebase's limit on parameters per event.
const firebaseParameterCount = 25;

/// Firebase's limit on string values.
const firebaseValueLength = 100;

/// Firebase's limit on user property names.
const firebaseUserPropertyNameLength = 24;

/// Mixpanel's key limit.
const mixpanelKeyLength = 255;

/// Clips [value] to [maxCharacters] and replaces spaces with underscores,
/// as the Swift `String.clean(maxCharacters:)` does.
String clean(String value, int maxCharacters) =>
    String.fromCharCodes(value.runes.take(maxCharacters)).replaceAll(' ', '_');

/// [value] as text, as the Swift Firebase service's `convertToString`: lists
/// become their items' text, sorted and joined with ", ". Null stays null.
String? describe(Object? value) => switch (value) {
  null => null,
  String() => value,
  DateTime() => value.toIso8601String(),
  Enum() => value.name,
  Iterable<Object?>() => (value.map(describe).nonNulls.toList()..sort()).join(
    ', ',
  ),
  _ => value.toString(),
};

/// [parameters] as Firebase Analytics takes them: only `String` and `num`
/// values. A bool becomes 1 or 0 (what the Swift app's `NSNumber` records);
/// a date, enum or list becomes text; anything else is dropped. Keys are
/// cleaned to 40 characters, text to 100, and only the first 25 kept.
Map<String, Object> firebaseParameters(Map<String, Object?>? parameters) {
  final result = <String, Object>{};
  for (final MapEntry(:key, :value) in (parameters ?? const {}).entries) {
    if (result.length == firebaseParameterCount) break;
    final converted = switch (value) {
      num() => value,
      bool() => value ? 1 : 0,
      String() ||
      DateTime() ||
      Enum() ||
      Iterable<Object?>() => clean(describe(value)!, firebaseValueLength),
      _ => null,
    };
    if (converted != null) result[clean(key, firebaseNameLength)] = converted;
  }
  return result;
}

/// [parameters] as Mixpanel takes them: strings, numbers, bools, dates, URIs
/// and lists of those; an enum becomes its name and anything else is
/// dropped, as the Swift service drops what isn't a `MixpanelType`. Keys are
/// clipped to 255 characters.
Map<String, Object> mixpanelProperties(Map<String, Object?>? parameters) => {
  for (final MapEntry(:key, :value) in (parameters ?? const {}).entries)
    String.fromCharCodes(key.runes.take(mixpanelKeyLength)): ?_mixpanelValue(
      value,
    ),
};

Object? _mixpanelValue(Object? value) => switch (value) {
  String() || num() || bool() || DateTime() || Uri() => value,
  Enum() => value.name,
  Iterable<Object?>() => value.map(_mixpanelValue).nonNulls.toList(),
  _ => null,
};
