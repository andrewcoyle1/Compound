import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// The same helper as in each Firestore repository's tests, cut down to the
// deletes and the collection read the coach makes.

/// A Firestore the server never answers, as when the device is offline:
/// every write stays pending until [refuse] fails them all, as the server
/// would on reconnecting.
class OfflineFirestore extends Fake implements FirebaseFirestore {
  final _server = Completer<void>();

  /// The paths written, in order.
  final writes = <String>[];

  /// What a read finds in the local cache, by path. A collection read
  /// returns every cached document directly in it.
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

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _QuerySnapshot([
    for (final MapEntry(key: documentPath, value: data)
        in _firestore.cached.entries)
      if (documentPath.startsWith('$path/') &&
          !documentPath.substring(path.length + 1).contains('/'))
        _Snapshot(_Document(_firestore, documentPath), data),
  ]);
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
  Future<void> delete() => _firestore._write(path);
}

// Sealed as above.
// ignore: subtype_of_sealed_class
class _Snapshot extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  new(this.reference, this._data);

  @override
  final DocumentReference<Map<String, dynamic>> reference;

  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic> data() => _data;
}

class _QuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  new(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}
