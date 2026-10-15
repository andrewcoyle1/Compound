import 'package:compound_models/compound_models.dart';
import 'package:program_repository/src/program_rules.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// The staging user's mesocycle, which their profile names as active
/// (`sampleUser`'s `submittedActiveMesocycleId`).
const sampleMesocycleId = 'sample-mesocycle';

const _sampleUserId = 'mock_user_123';

/// `mock_user_123`'s own copy of the bundled Push/Pull/Legs, the program
/// recommended for training daily, started two weeks before [now]. Its ids
/// are fixed (`sample-mesocycle`, then `sample-mesocycle-<n>`) so staging
/// is the same on every launch.
List<Mesocycle> sampleMesocycles({required DateTime now}) {
  var count = 0;
  final copy = copyMesocycle(
    PrebuiltCatalogue.instance.mesocycles.firstWhere(
      (mesocycle) => mesocycle.id == 'program-push-pull-legs',
    ),
    authorId: _sampleUserId,
    now: now.subtract(const Duration(days: 14)),
    newId: () => count++ == 0 ? sampleMesocycleId : '$sampleMesocycleId-$count',
  );
  return [copy];
}

/// The macrocycle following [sampleMesocycles] alone, active since it was
/// started, two weeks before [now].
List<Macrocycle> sampleMacrocycles({required DateTime now}) {
  final started = now.subtract(const Duration(days: 14));
  return [
    Macrocycle(
      id: 'sample-macrocycle',
      authorId: _sampleUserId,
      name: 'Push/Pull/Legs',
      mesocycleIds: const [sampleMesocycleId],
      mesocycleStartedAt: started,
      dateCreated: started,
      dateModified: started,
    ),
  ];
}
