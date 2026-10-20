import 'dart:async';

import 'package:checkin_repository/src/checkin_repository.dart';
import 'package:compound_models/compound_models.dart';

/// [CheckInRepository] in memory, for the staging flavor and tests. Seed it
/// with `sampleStrategySettings`, `sampleCheckInRecord`, `sampleLoggingBreak`
/// and `sampleDayAnnotations`.
///
/// It holds each document as Firestore would, as a map, and writes the same
/// way the Firestore implementation does: merged field by field, deleting
/// the fields that one deletes, and every watcher sees the change.
class InMemoryCheckInRepository implements CheckInRepository {
  /// Creates an [InMemoryCheckInRepository] holding each document under its
  /// author's id.
  new({
    List<NutritionStrategySettings> settings = const [],
    List<NutritionDayAnnotation> annotations = const [],
    List<LoggingBreak> loggingBreaks = const [],
    List<CheckInRecord> records = const [],
  }) {
    for (final s in settings) {
      _documents[_settingsPath(s.authorId)] = s.toFirestore();
    }
    for (final a in annotations) {
      _documents[_annotationPath(a.authorId, a.dayKey)] = a.toFirestore();
    }
    for (final b in loggingBreaks) {
      _documents[_breakPath(b.authorId)] = b.toFirestore();
    }
    for (final r in records) {
      _documents[_recordPath(r.authorId)] = r.toFirestore();
    }
  }

  final _documents = <String, Map<String, Object?>>{};
  final _changes = StreamController<void>.broadcast(sync: true);

  static String _settingsPath(String uid) =>
      'users/$uid/nutrition_strategy_settings/nutrition_strategy_settings';
  static String _annotations(String uid) =>
      'users/$uid/nutrition_day_annotations/';
  static String _annotationPath(String uid, String dayKey) =>
      '${_annotations(uid)}$dayKey';
  static String _breakPath(String uid) =>
      'users/$uid/logging_break/${LoggingBreak.documentId}';
  static String _recordPath(String uid) =>
      'users/$uid/check_in_record/${CheckInRecord.documentId}';

  @override
  Stream<NutritionStrategySettings> watchStrategySettings(String uid) => _watch(
    () =>
        _read(_settingsPath(uid), NutritionStrategySettings.fromFirestore) ??
        NutritionStrategySettings(authorId: uid),
  );

  @override
  Future<void> saveStrategySettings(NutritionStrategySettings settings) =>
      _merge(
        _settingsPath(settings.authorId),
        settings.toFirestore(),
        deleting: [
          if (settings.calculationStartDate == null)
            NutritionStrategySettingsKeys.calculationStartDate,
        ],
      );

  @override
  Stream<List<NutritionDayAnnotation>> watchDayAnnotations(String uid) =>
      _watch(() {
        final prefix = _annotations(uid);
        final paths =
            _documents.keys.where((path) => path.startsWith(prefix)).toList()
              ..sort();
        return [
          for (final path in paths)
            ?_read(path, NutritionDayAnnotation.fromFirestore),
        ];
      });

  @override
  Future<void> saveDayAnnotations(
    String uid,
    List<NutritionDayAnnotation> annotations,
  ) async {
    for (final annotation in annotations) {
      final path = _annotationPath(uid, annotation.dayKey);
      if (annotation.isEmpty) {
        _documents.remove(path);
      } else {
        _documents[path] = {...?_documents[path], ...annotation.toFirestore()};
      }
    }
    _changes.add(null);
  }

  @override
  Stream<LoggingBreak?> watchLoggingBreak(String uid) =>
      _watch(() => _read(_breakPath(uid), LoggingBreak.fromFirestore));

  @override
  Future<void> startLoggingBreak(String uid, DateTime startDate) => _merge(
    _breakPath(uid),
    LoggingBreak(authorId: uid, startDate: startDate).toFirestore(),
    deleting: const [LoggingBreakKeys.endDate],
  );

  @override
  Future<void> endLoggingBreak(String uid, DateTime endDate) async {
    final current = _read(_breakPath(uid), LoggingBreak.fromFirestore);
    if (current == null || current.endDate != null) return;
    await _merge(_breakPath(uid), {LoggingBreakKeys.endDate: endDate});
  }

  @override
  Stream<CheckInRecord?> watchCheckInRecord(String uid) =>
      _watch(() => _read(_recordPath(uid), CheckInRecord.fromFirestore));

  @override
  Future<void> markCheckInCompleted(String uid, DateTime weekStart) =>
      _markRecord(uid, CheckInRecordKeys.lastCompletedWeekStart, weekStart);

  @override
  Future<void> markCheckInSkipped(String uid, DateTime weekStart) =>
      _markRecord(uid, CheckInRecordKeys.lastSkippedWeekStart, weekStart);

  Future<void> _markRecord(String uid, String field, DateTime weekStart) =>
      _merge(_recordPath(uid), {
        CheckInRecordKeys.id: CheckInRecord.documentId,
        CheckInRecordKeys.authorId: uid,
        field: weekStart,
      });

  /// [data] merged over the document at [path], as `set(merge: true)`
  /// does, with each of [deleting] removed.
  Future<void> _merge(
    String path,
    Map<String, Object?> data, {
    List<String> deleting = const [],
  }) async {
    _documents[path] = {...?_documents[path], ...data}
      ..removeWhere((key, _) => deleting.contains(key));
    _changes.add(null);
  }

  /// The document at [path], or null when there is none. Everything stored
  /// came from a model, so it always decodes.
  T? _read<T>(String path, T Function(Map<String, Object?>) decode) {
    final data = _documents[path];
    return data == null ? null : decode(data);
  }

  /// [read] now and after every write, as a Firestore listener emits.
  Stream<T> _watch<T>(T Function() read) => Stream.multi((listener) {
    listener.add(read());
    final subscription = _changes.stream.listen((_) => listener.add(read()));
    // Not `subscription.cancel` itself: `first` would wait on the Future
    // that returns, which never completes under a widget test's fake clock.
    listener.onCancel = () => unawaited(subscription.cancel());
  });
}
