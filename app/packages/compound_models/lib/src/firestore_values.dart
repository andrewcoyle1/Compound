/// Readers for Firestore values that follow the Swift decoder
/// (`FirebaseDataDecoder`) exactly, beyond what a plain cast does.
library;

/// An `Int` field as Swift reads it: an int, or a double with no fractional
/// part. Anything else, a bool included, throws a [FormatException].
int readInt(Object? value) => switch (value) {
  final int whole => whole,
  final double number when number.isFinite && number % 1 == 0 => number.toInt(),
  _ => throw FormatException('Not an integer', value),
};

/// An optional `Int` field: null or absent reads as null, anything else as
/// [readInt] reads it.
int? readOptionalInt(Object? value) => value == null ? null : readInt(value);

/// An optional `Double` field: any number, as Swift widens an integer.
double? readOptionalDouble(Object? value) => (value as num?)?.toDouble();

/// A `[String]` field.
List<String> readStringList(Object? value) =>
    List<String>.from(value! as List<Object?>);

/// An `Int` field Swift reads with `try?`: whatever [readInt] refuses reads
/// as null.
int? lenientInt(Object? value) => switch (value) {
  final int whole => whole,
  final double number when number.isFinite && number % 1 == 0 => number.toInt(),
  _ => null,
};

/// A `Double` field Swift reads with `try?`: anything but a number reads as
/// null.
double? lenientDouble(Object? value) => value is num ? value.toDouble() : null;

/// A `String` field Swift reads with `try?`.
String? lenientString(Object? value) => value is String ? value : null;

/// A `[String]` field Swift reads with `try?`: anything but a list of
/// strings reads as null.
List<String>? lenientStringList(Object? value) =>
    value is List && value.every((element) => element is String)
    ? List<String>.from(value)
    : null;

/// A list read element by element (Swift's `decodeLossyArray`): an element
/// [decode] throws on is skipped, and anything but a list reads as null.
List<T>? lossyList<T>(Object? value, T Function(Object? element) decode) {
  if (value is! List) return null;
  final decoded = <T>[];
  for (final element in value) {
    try {
      decoded.add(decode(element));
    } on Object {
      // Swift's `try?`: an unreadable element costs only itself.
    }
  }
  return decoded;
}

/// A nested map, as Firestore returns one.
Map<String, Object?> readMap(Object? value) => value! as Map<String, Object?>;
