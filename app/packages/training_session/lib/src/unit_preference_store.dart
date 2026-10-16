/// Each exercise's units, kept on the device per account
/// (`ExerciseUnitPreferenceManager`, which keeps them in `UserDefaults`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:compound_models/compound_models.dart' as m;
import 'package:training_session/src/session_load.dart';

/// The units chosen for each exercise, by account and exercise (template)
/// id, under Swift's keys (`exercise_unit_preference_<uid>_<templateId>`),
/// so a second account on the device never reads the first one's. Kept in
/// a JSON file when given, else in memory for the staging flavor and tests.
///
/// ponytail: one small JSON file of its own, as the app's proposal
/// dismissals are; the device key-value store planned for slice 9 can
/// absorb it.
class UnitPreferenceStore {
  /// Reads what `file` holds; a file that cannot be read starts empty.
  new({this._file}) {
    final file = _file;
    if (file == null || !file.existsSync()) return;
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map<String, Object?>) return;
      for (final MapEntry(:key, :value) in json.entries) {
        if (value is Map<String, Object?>) _stored[key] = value;
      }
    } on FormatException {
      // A file this build cannot read only puts the units back to default.
    }
  }

  final File? _file;
  final _stored = <String, Map<String, Object?>>{};
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Fires after every change.
  Stream<void> get changes => _changes.stream;

  /// The key a preference is kept under.
  static String key(String uid, String templateId) =>
      'exercise_unit_preference_${uid}_$templateId';

  /// [uid]'s units for [templateId]: those chosen, else [user]'s app-wide
  /// units (never kept, as they follow the profile). No account reads the
  /// defaults.
  UnitPreference of(String? uid, String templateId, {m.UserModel? user}) {
    final fallback = UnitPreference.fromProfile(user);
    final stored = uid == null ? null : _stored[key(uid, templateId)];
    if (stored == null) return fallback;
    return UnitPreference(
      weightUnit: _weight(stored['weightUnit']) ?? fallback.weightUnit,
      // Stored before the flag existed, it was stored because the user
      // changed something.
      weightUnitIsChosen: stored['weightUnitIsChosen'] as bool? ?? true,
      distanceUnit: _distance(stored['distanceUnit']) ?? fallback.distanceUnit,
    );
  }

  /// The weight unit kept for each of [uid]'s exercises, by exercise id;
  /// an exercise left out has the profile's.
  Map<String, m.ExerciseWeightUnit> weightUnits(String uid) => {
    for (final value in _stored.values)
      if ((value['exerciseModelId'], _weight(value['weightUnit']))
          case (final String id, final unit?)
          when _stored[key(uid, id)] == value)
        id: unit,
  };

  /// [unit] chosen as [templateId]'s weight unit.
  void setWeightUnit(
    String? uid,
    String templateId,
    m.ExerciseWeightUnit unit, {
    m.UserModel? user,
  }) => _save(uid, templateId, user, (current) {
    return UnitPreference(
      weightUnit: unit,
      weightUnitIsChosen: true,
      distanceUnit: current.distanceUnit,
    );
  });

  /// [unit] chosen as [templateId]'s distance unit.
  void setDistanceUnit(
    String? uid,
    String templateId,
    DistanceUnit unit, {
    m.UserModel? user,
  }) => _save(uid, templateId, user, (current) {
    return UnitPreference(
      weightUnit: current.weightUnit,
      weightUnitIsChosen: current.weightUnitIsChosen,
      distanceUnit: unit,
    );
  });

  void _save(
    String? uid,
    String templateId,
    m.UserModel? user,
    UnitPreference Function(UnitPreference current) change,
  ) {
    if (uid == null) return;
    final next = change(of(uid, templateId, user: user));
    _stored[key(uid, templateId)] = {
      'exerciseModelId': templateId,
      'weightUnit': next.weightUnit.value,
      'distanceUnit': next.distanceUnit.name,
      'weightUnitIsChosen': next.weightUnitIsChosen,
    };
    _file?.parent.createSync(recursive: true);
    _file?.writeAsStringSync(jsonEncode(_stored), flush: true);
    _changes.add(null);
  }

  static m.ExerciseWeightUnit? _weight(Object? value) => m
      .ExerciseWeightUnit
      .values
      .where((unit) => unit.value == value)
      .firstOrNull;

  static DistanceUnit? _distance(Object? value) =>
      DistanceUnit.values.where((unit) => unit.name == value).firstOrNull;
}
