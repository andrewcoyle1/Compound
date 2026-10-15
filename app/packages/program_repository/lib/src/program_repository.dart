import 'package:compound_models/compound_models.dart';

/// The signed-in user's mesocycles and macrocycles.
abstract interface class ProgramRepository {
  /// The mesocycles at `users/{uid}/mesocycles`, as `MesocycleManager`'s
  /// listener reads them. Re-emitted on every change.
  Stream<List<Mesocycle>> watchMesocycles(String uid);

  /// The macrocycles at `users/{uid}/macrocycles`, as `MacrocycleManager`'s
  /// listener reads them. Re-emitted on every change; [runningMacrocycle]
  /// picks the one being followed.
  Stream<List<Macrocycle>> watchMacrocycles(String uid);

  /// Saves [mesocycle] to `users/{mesocycle.authorId}/mesocycles/{id}`,
  /// merged over anything there, as `MesocycleManager.saveMesocycle` does
  /// (`saveDocument` is `setData(merge: true)`). Its day plans are a list,
  /// so a save replaces them whole.
  Future<void> saveMesocycle(Mesocycle mesocycle);

  /// Saves [macrocycle] to `users/{macrocycle.authorId}/macrocycles/{id}`,
  /// merged, as `MacrocycleManager.save` does.
  ///
  /// A null `startMicrocycleIndex` deletes the stored one. Swift's merge
  /// leaves it, so moving to the next mesocycle keeps the old join point
  /// (`swift-findings.md`).
  Future<void> saveMacrocycle(Macrocycle macrocycle);

  /// Deletes `users/{uid}/mesocycles/{id}` (`MesocycleManager
  /// .deleteMesocycle`).
  Future<void> deleteMesocycle(String uid, String id);

  /// Deletes `users/{uid}/macrocycles/{id}` (`MacrocycleManager.delete`).
  Future<void> deleteMacrocycle(String uid, String id);
}

/// The macrocycle being followed, or just finished and waiting on a repeat:
/// the active or completed one changed last, the first of them on a tie
/// (`MacrocycleManager.currentMacrocycle`). Null when there is none.
Macrocycle? runningMacrocycle(Iterable<Macrocycle> macrocycles) => macrocycles
    .where(isRunning)
    .fold<Macrocycle?>(
      null,
      (newest, macrocycle) =>
          newest == null ||
              newest.dateModified.isBefore(macrocycle.dateModified)
          ? macrocycle
          : newest,
    );

/// Whether [macrocycle] is active or completed, the states starting another
/// one ends.
bool isRunning(Macrocycle macrocycle) =>
    macrocycle.status == MacrocycleStatus.active ||
    macrocycle.status == MacrocycleStatus.completed;
