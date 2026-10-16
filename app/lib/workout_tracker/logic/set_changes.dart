import 'package:compound_models/compound_models.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

/// What changing one of an exercise's sets would take with it, for the
/// questions the set table asks first. Shared by the live tracker and a
/// finished workout's editor.
extension SetChanges on WorkoutExerciseModel {
  /// How many logged rows making [setId] [choice] would delete: sub-rows
  /// the new type has no use for (`onSetTypeSelected`).
  int loggedRowsLostBy(String setId, r.SetTypeChoice choice) {
    if (!sets.any((s) => s.id == setId)) return 0;
    final kept = {
      for (final row in r.ActiveWorkout.applying(
        choice,
        setId,
        sets.map(rulesSet).toList(),
        firstSubSetId: '',
        dropWeightKg: null,
      ))
        row.id,
    };
    return sets
        .where((s) => s.completedAt != null && !kept.contains(s.id))
        .length;
  }

  /// The drops and mini-sets deleting [setId] would take with it.
  ({int drops, int minis}) subSetsRemovedBy(String setId) =>
      r.ActiveWorkout.subSetsRemovedByDeleting(
        setId,
        sets.map(rulesSet).toList(),
      );
}
