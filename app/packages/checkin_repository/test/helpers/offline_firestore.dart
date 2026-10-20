import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// The same helper is in each Firestore repository's tests.

/// A Firestore the server never answers, as when the device is offline:
/// every write stays pending until [refuse] fails them all, as the server
/// would on reconnecting.
class OfflineFirestore extends Fake implements FirebaseFirestore {
  final _server = Completer<void>();

  /// The paths written, in order (a batch as `batch`).
  final writes = <String>[];

  /// What a read finds in the local cache, by path.
  final cached = <String, Map<String, dynamic>>{};

  /// Fails every write so far, and every later one, with [code].
  void refuse(String code) => _server.completeError(
    FirebaseException(plugin: 'cloud_firestore', code: code),
  );

  Future<void> _write(String path) {
    writes.add(path);
    return _server.future;
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);

  @override
  WriteBatch batch() => _Batch(this);
}

// cloud_firestore marks these @sealed; a test fake is the exception it
// allows, as fake_cloud_firestore does.
// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  new(this._firestore, this.path);

  final OfflineFirestore _firestore;

  @override
  final String path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      _Document(_firestore, '$path/$id');
}

// Sealed as above.
// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  new(this._firestore, this.path);

  final OfflineFirestore _firestore;

  @override
  final String path;

  @override
  CollectionReference<Map<String, dynamic>> collection(String name) =>
      _Collection(_firestore, '$path/$name');

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) =>
      _firestore._write(path);

  @override
  Future<void> update(Map<Object, Object?> data) => _firestore._write(path);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(this, _firestore.cached[path]);
}

// Sealed as above.
// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  new(this.reference, this._data);

  @override
  final DocumentReference<Map<String, dynamic>> reference;

  final Map<String, dynamic>? _data;

  @override
  Map<String, dynamic>? data() => _data;
}

class _Batch extends Fake implements WriteBatch {
  new(this._firestore);

  final OfflineFirestore _firestore;

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {}

  @override
  void delete(DocumentReference<Object?> document) {}

  @override
  Future<void> commit() => _firestore._write('batch');
}
