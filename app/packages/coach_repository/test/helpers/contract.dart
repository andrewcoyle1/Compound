// Fixtures from contracts/firestore, as Firestore holds them. A slimmer
// copy of the helper in each repository package that writes: this one only
// reads.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';

/// The fixture `contracts/firestore/<model>/<name>.json` as Firestore holds
/// it: dates as [Timestamp]s.
Map<String, Object?> storedFixture(String model, String name) => _timestamps(
  taggedJsonToFirestore(
    jsonDecode(
      File('../../../contracts/firestore/$model/$name.json').readAsStringSync(),
    ) as Map<String, Object?>,
  ),
);

Map<String, Object?> _timestamps(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _timestamp(value)));

Object? _timestamp(Object? value) => switch (value) {
  final DateTime date => Timestamp.fromDate(date),
  final Map<String, Object?> map => _timestamps(map),
  final List<Object?> list => list.map(_timestamp).toList(),
  _ => value,
};
