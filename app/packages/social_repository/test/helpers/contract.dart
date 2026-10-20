// The Firestore contract as these tests check it: fixtures from
// contracts/firestore, and a strict comparison of what was stored with them.
// The same helper is in each repository package that writes.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fixture `contracts/firestore/<model>/<name>.json`, as tagged JSON.
Map<String, Object?> taggedFixture(String model, String name) => jsonDecode(
  File('../../../contracts/firestore/$model/$name.json').readAsStringSync(),
) as Map<String, Object?>;

/// The fixture as a model's `fromFirestore` takes it: dates as [DateTime].
Map<String, Object?> modelFixture(String model, String name) =>
    taggedJsonToFirestore(taggedFixture(model, name));

/// The fixture as Firestore holds it: dates as [Timestamp].
Map<String, Object?> storedFixture(String model, String name) =>
    _timestamps(modelFixture(model, name));

Map<String, Object?> _timestamps(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _timestamp(value)));

Object? _timestamp(Object? value) => switch (value) {
  final DateTime date => Timestamp.fromDate(date),
  final Map<String, Object?> map => _timestamps(map),
  final List<Object?> list => list.map(_timestamp).toList(),
  _ => value,
};

/// A stored document as tagged JSON, comparable with a fixture. Fails on a
/// [DateTime] stored as itself: every date must reach Firestore as a
/// [Timestamp].
Map<String, Object?> storedAsTagged(Map<String, Object?> stored) =>
    firestoreToTaggedJson(_dates(stored));

Map<String, Object?> _dates(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _date(value)));

Object? _date(Object? value) => switch (value) {
  final Timestamp timestamp => timestamp.toDate().toUtc(),
  final DateTime date => fail('$date was stored as a DateTime'),
  final Map<String, Object?> map => _dates(map),
  final List<Object?> list => list.map(_date).toList(),
  _ => value,
};

/// Equal values of the same JSON type: an int never matches a double, so a
/// write cannot change a field's Firestore type unnoticed (as
/// compound_models' contract test compares).
Matcher strictlyEquals(Object? expected) => predicate<Object?>(
  (actual) => _strictEqual(actual, expected),
  'strictly equals ${jsonEncode(expected)}',
);

bool _strictEqual(Object? a, Object? b) => switch ((a, b)) {
  (final Map<String, Object?> x, final Map<String, Object?> y) =>
    x.length == y.length &&
        x.keys.every((k) => y.containsKey(k) && _strictEqual(x[k], y[k])),
  (final List<Object?> x, final List<Object?> y) =>
    x.length == y.length &&
        [for (var i = 0; i < x.length; i++) i]
            .every((i) => _strictEqual(x[i], y[i])),
  _ => a.runtimeType == b.runtimeType && a == b,
};

/// A model's map as Firestore stores it: dates as [Timestamp]s.
Map<String, Object?> asStored(Map<String, Object?> data) => _timestamps(data);
