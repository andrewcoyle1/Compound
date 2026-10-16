import 'dart:convert';
import 'dart:io';

import 'package:device_store/device_store.dart';

/// Moves what development builds before the device store kept in JSON
/// files of their own into [store], then deletes the files: the proposals
/// waved away (#130) and each exercise's units (#163), both already under
/// Swift's keys. A value the store already holds wins; a file that cannot
/// be read is deleted unread, which only resets a dismissal or a unit.
void migrateDeviceFiles(DeviceStore store, Directory support) {
  _migrate(File('${support.path}/dismissed_target_proposals.json'), (
    key,
    value,
  ) {
    if (value is num && store.getDouble(key) == null) {
      store.setDouble(key, value.toDouble());
    }
  });
  _migrate(File('${support.path}/exercise_unit_preferences.json'), (
    key,
    value,
  ) {
    if (value is Map && store.getString(key) == null) {
      store.setString(key, jsonEncode(value));
    }
  });
}

void _migrate(File file, void Function(String key, Object? value) keep) {
  if (!file.existsSync()) return;
  try {
    if (jsonDecode(file.readAsStringSync()) case final Map<String, Object?> m) {
      m.forEach(keep);
    }
  } on FormatException {
    // Nothing worth keeping.
  }
  file.deleteSync();
}
