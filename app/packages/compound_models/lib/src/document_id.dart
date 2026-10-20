import 'package:uuid/uuid.dart';

/// A new document id in the Swift app's form, `UUID().uuidString`: a
/// random (version 4) UUID in upper case, such as
/// `E621E1F8-C36C-495A-93FC-0C247A3E6E5F`.
String newDocumentId() => const Uuid().v4().toUpperCase();
