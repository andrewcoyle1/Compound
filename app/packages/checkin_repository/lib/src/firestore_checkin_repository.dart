import 'dart:developer' as developer;

import 'package:checkin_repository/src/checkin_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';

/// Called with a document's path when it cannot be decoded and is skipped.
typedef CheckInDecodeErrorHandler = void Function(
  String path,
  Object error,
  StackTrace stackTrace,
);

/// [CheckInRepository] on Cloud Firestore.
///
/// A document that does not decode is skipped and reported to
/// `onDecodeError`, as the Swift app's sync engine skips it. Writes go
/// through the models' `toFirestore`, with dates stored as Timestamps, and
/// merge (`docs/specs/flutter/firestore-contract.md`, Policy). A write
/// completes once Firestore has it locally, online or not ([writeLocally]).
class FirestoreCheckInRepository implements CheckInRepository {
  /// Creates a [FirestoreCheckInRepository] on `firestore`. Decode failures
  /// go to [onDecodeError], or to `dart:developer`'s log when it is null,
  /// and writes the server refuses go to `onWriteError`.
  new({
    required this._firestore,
    CheckInDecodeErrorHandler? onDecodeError,
    this._onWriteError = logWriteError,
  }) : _onDecodeError = onDecodeError ?? _log;

  final FirebaseFirestore _firestore;
  final CheckInDecodeErrorHandler _onDecodeError;
  final WriteErrorReporter _onWriteError;

  CollectionReference<Map<String, dynamic>> _collection(
    String uid,
    String name,
  ) => _firestore.collection('users').doc(uid).collection(name);

  DocumentReference<Map<String, dynamic>> _settings(String uid) => _collection(
    uid,
    'nutrition_strategy_settings',
  ).doc('nutrition_strategy_settings');

  DocumentReference<Map<String, dynamic>> _break(String uid) =>
      _collection(uid, 'logging_break').doc(LoggingBreak.documentId);

  DocumentReference<Map<String, dynamic>> _record(String uid) =>
      _collection(uid, 'check_in_record').doc(CheckInRecord.documentId);

  @override
  Stream<NutritionStrategySettings> watchStrategySettings(String uid) =>
      _settings(uid).snapshots().map(
        (document) =>
            _decodeDocument(
              document,
              NutritionStrategySettings.fromFirestore,
            ) ??
            NutritionStrategySettings(authorId: uid),
      );

  @override
  Future<void> saveStrategySettings(NutritionStrategySettings settings) =>
      _merge(_settings(settings.authorId), {
        ..._toFirestore(settings.toFirestore()),
        if (settings.calculationStartDate == null)
          NutritionStrategySettingsKeys.calculationStartDate:
              FieldValue.delete(),
      });

  @override
  Stream<List<NutritionDayAnnotation>> watchDayAnnotations(String uid) =>
      _collection(uid, 'nutrition_day_annotations').snapshots().map(
        (snapshot) => [
          for (final document in snapshot.docs)
            ?_decode(
              document.reference.path,
              document.data(),
              NutritionDayAnnotation.fromFirestore,
            ),
        ]..sort((a, b) => a.dayKey.compareTo(b.dayKey)),
      );

  /// One batch, reported under the collection's path if the server refuses
  /// it.
  @override
  Future<void> saveDayAnnotations(
    String uid,
    List<NutritionDayAnnotation> annotations,
  ) {
    final batch = _firestore.batch();
    final collection = _collection(uid, 'nutrition_day_annotations');
    for (final annotation in annotations) {
      final document = collection.doc(annotation.dayKey);
      if (annotation.isEmpty) {
        batch.delete(document);
      } else {
        batch.set(
          document,
          _toFirestore(annotation.toFirestore()),
          SetOptions(merge: true),
        );
      }
    }
    return writeLocally(collection.path, batch.commit, _onWriteError);
  }

  @override
  Stream<LoggingBreak?> watchLoggingBreak(String uid) => _break(uid)
      .snapshots()
      .map((document) => _decodeDocument(document, LoggingBreak.fromFirestore));

  @override
  Future<void> startLoggingBreak(String uid, DateTime startDate) =>
      _merge(_break(uid), {
        ..._toFirestore(
          LoggingBreak(authorId: uid, startDate: startDate).toFirestore(),
        ),
        LoggingBreakKeys.endDate: FieldValue.delete(),
      });

  /// Reads the open break first, so it waits for that read: offline,
  /// Firestore answers from its cache once it knows it cannot reach the
  /// server. The write itself does not wait for the server.
  @override
  Future<void> endLoggingBreak(String uid, DateTime endDate) async {
    final current = _decodeDocument(
      await _break(uid).get(),
      LoggingBreak.fromFirestore,
    );
    if (current == null || current.endDate != null) return;
    await _merge(
      _break(uid),
      _toFirestore(
        LoggingBreak(
          id: current.id,
          authorId: current.authorId,
          startDate: current.startDate,
          endDate: endDate,
        ).toFirestore(),
      ),
    );
  }

  @override
  Stream<CheckInRecord?> watchCheckInRecord(String uid) => _record(uid)
      .snapshots()
      .map(
        (document) => _decodeDocument(document, CheckInRecord.fromFirestore),
      );

  @override
  Future<void> markCheckInCompleted(String uid, DateTime weekStart) =>
      _markRecord(uid, CheckInRecordKeys.lastCompletedWeekStart, weekStart);

  @override
  Future<void> markCheckInSkipped(String uid, DateTime weekStart) =>
      _markRecord(uid, CheckInRecordKeys.lastSkippedWeekStart, weekStart);

  Future<void> _markRecord(String uid, String field, DateTime weekStart) =>
      _merge(_record(uid), {
        CheckInRecordKeys.id: CheckInRecord.documentId,
        CheckInRecordKeys.authorId: uid,
        field: Timestamp.fromDate(weekStart),
      });

  /// Merges [data], already in Firestore's values, into [document].
  Future<void> _merge(
    DocumentReference<Map<String, dynamic>> document,
    Map<String, Object?> data,
  ) => writeLocally(
    document.path,
    () => document.set(data, SetOptions(merge: true)),
    _onWriteError,
  );

  T? _decodeDocument<T>(
    DocumentSnapshot<Map<String, dynamic>> document,
    T Function(Map<String, Object?>) decode,
  ) {
    final data = document.data();
    return data == null ? null : _decode(document.reference.path, data, decode);
  }

  T? _decode<T>(
    String path,
    Map<String, Object?> data,
    T Function(Map<String, Object?>) decode,
  ) {
    try {
      return decode(_fromFirestore(data));
    } on Object catch (error, stackTrace) {
      _onDecodeError(path, error, stackTrace);
      return null;
    }
  }

  static void _log(String path, Object error, StackTrace stackTrace) =>
      developer.log(
        'Skipped $path: it does not decode',
        name: 'checkin_repository',
        error: error,
        stackTrace: stackTrace,
      );
}

// ponytail: the same converter as the other repositories'; the models are
// flat, so it needs no recursion.
/// Firestore's values to the models': a [Timestamp] becomes a UTC
/// [DateTime].
Map<String, Object?> _fromFirestore(Map<String, Object?> data) => data.map(
  (key, value) =>
      MapEntry(key, value is Timestamp ? value.toDate().toUtc() : value),
);

/// The models' values to Firestore's: a [DateTime] becomes a [Timestamp], as
/// Swift's encoder stores a `Date`.
Map<String, Object?> _toFirestore(Map<String, Object?> data) => data.map(
  (key, value) =>
      MapEntry(key, value is DateTime ? Timestamp.fromDate(value) : value),
);
