import 'dart:math';

/// A new document id in the Swift app's form, `UUID().uuidString`: a
/// random (version 4) UUID in upper case, such as
/// `E621E1F8-C36C-495A-93FC-0C247A3E6E5F`.
String newDocumentId([Random? random]) {
  final generator = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => generator.nextInt(256));
  bytes[6] = bytes[6] & 0x0f | 0x40; // version 4
  bytes[8] = bytes[8] & 0x3f | 0x80; // RFC 4122 variant
  final hex = [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')]
      .join()
      .toUpperCase();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
