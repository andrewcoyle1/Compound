import 'dart:async';

import 'package:compound_models/compound_models.dart';
import 'package:program_repository/src/program_repository.dart';

/// [ProgramRepository] in memory, for the staging flavor and tests. Seed it
/// with `sampleMesocycles` and `sampleMacrocycles`.
///
/// Saves merge over the stored document field by field, as a Firestore
/// merge does, and every watcher sees the change.
class InMemoryProgramRepository implements ProgramRepository {
  /// Creates an [InMemoryProgramRepository] holding everyone's [mesocycles]
  /// and [macrocycles]; each read keeps the ones its user owns.
  new({
    List<Mesocycle> mesocycles = const [],
    List<Macrocycle> macrocycles = const [],
  }) : _mesocycles = List.of(mesocycles),
       _macrocycles = List.of(macrocycles);

  final List<Mesocycle> _mesocycles;
  final List<Macrocycle> _macrocycles;
  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  Stream<List<Mesocycle>> watchMesocycles(String uid) => _watch(
    () => [
      for (final mesocycle in _mesocycles)
        if (mesocycle.authorId == uid) mesocycle,
    ],
  );

  @override
  Stream<List<Macrocycle>> watchMacrocycles(String uid) => _watch(
    () => [
      for (final macrocycle in _macrocycles)
        if (macrocycle.authorId == uid) macrocycle,
    ],
  );

  @override
  Future<void> saveMesocycle(Mesocycle mesocycle) async => _merge(
    _mesocycles,
    mesocycle,
    (stored) =>
        stored.authorId == mesocycle.authorId && stored.id == mesocycle.id,
    Mesocycle.fromFirestore,
    (model) => model.toFirestore(),
  );

  @override
  Future<void> saveMacrocycle(Macrocycle macrocycle) async => _merge(
    _macrocycles,
    macrocycle,
    (stored) =>
        stored.authorId == macrocycle.authorId && stored.id == macrocycle.id,
    Macrocycle.fromFirestore,
    (model) => model.toFirestore(),
  );

  /// Writes [model] into [documents] as a Firestore merge does: over the
  /// document [isSame] finds, field by field, or as a new one.
  void _merge<T>(
    List<T> documents,
    T model,
    bool Function(T) isSame,
    T Function(Map<String, Object?>) decode,
    Map<String, Object?> Function(T) encode,
  ) {
    final index = documents.indexWhere(isSame);
    if (index < 0) {
      documents.add(model);
    } else {
      documents[index] = decode({
        ...encode(documents[index]),
        ...encode(model),
      });
    }
    _changes.add(null);
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
