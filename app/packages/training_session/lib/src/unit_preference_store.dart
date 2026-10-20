/// Each exercise's units, kept on the device per account
/// (`ExerciseUnitPreferenceManager`, which keeps them in `UserDefaults`).
library;

import 'dart:async';
import 'dart:convert';

import 'package:compound_models/compound_models.dart' as m;
import 'package:device_store/device_store.dart';
import 'package:training_session/src/session_load.dart';

/// The units chosen for each exercise, by account and exercise (template)
/// id, under Swift's keys (`exercise_unit_preference_<uid>_<templateId>`),
/// so a second account on the device never reads the first one's. Each is
/// a JSON object in the device store (Swift encodes the same fields as
/// `Data`).
class UnitPreferenceStore {
  /// Keeps them in [store]; in memory when left out.
  new({DeviceStore? store}) : _store = store ?? InMemoryDeviceStore();

  final DeviceStore _store;
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Fires after every change.
  Stream<void> get changes => _changes.stream;

  /// The prefix of every key a preference is kept under.
  static const keyPrefix = 'exercise_unit_preference_';

  /// The key a preference is kept under.
  static String key(String uid, String templateId) =>
      '$keyPrefix${uid}_$templateId';

  Map<String, Object?>? _stored(String key) {
    final json = _store.getString(key);
    if (json == null) return null;
    try {
      return switch (jsonDecode(json)) {
        final Map<String, Object?> value => value,
        _ => null,
      };
    } on FormatException {
      // A value this build cannot read only puts the units back to default.
      return null;
    }
  }

  /// [uid]'s units for [templateId]: those chosen, else [user]'s app-wide
  /// units (never kept, as they follow the profile). No account reads the
  /// defaults.
  UnitPreference of(String? uid, String templateId, {m.UserModel? user}) {
    final fallback = UnitPreference.fromProfile(user);
    final stored = uid == null ? null : _stored(key(uid, templateId));
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
  /// an exercise left out has the profile's. A key is matched back from
  /// its stored exercise id, so one uid prefixing another reads nothing.
  Map<String, m.ExerciseWeightUnit> weightUnits(String uid) => {
    for (final stored
        in _store.keys
            .where((k) => k.startsWith('$keyPrefix${uid}_'))
            .map((k) => (k, _stored(k))))
      if ((stored.$2?['exerciseModelId'], _weight(stored.$2?['weightUnit']))
          case (final String id, final unit?) when stored.$1 == key(uid, id))
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
    _store.setString(
      key(uid, templateId),
      jsonEncode({
        'exerciseModelId': templateId,
        'weightUnit': next.weightUnit.value,
        'distanceUnit': next.distanceUnit.name,
        'weightUnitIsChosen': next.weightUnitIsChosen,
      }),
    );
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
