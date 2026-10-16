import 'package:compound_models/compound_models.dart';
import 'package:program_repository/src/program_rules.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// The staging user's mesocycle, which their profile names as active
/// (`sampleUser`'s `submittedActiveMesocycleId`).
const sampleMesocycleId = 'sample-mesocycle';

const _sampleUserId = 'mock_user_123';

/// The ids of the staging user's two saved, unfollowed mesocycles.
const sampleInactiveMesocycleIds = ['sample-upper-lower', 'sample-full-body'];

/// `mock_user_123`'s own copies of the bundled programs: Push/Pull/Legs
/// first, the one recommended for training daily and followed since two
/// weeks before [now], then Upper/Lower and Full Body, saved but not
/// followed. Ids are fixed (`<id>`, then `<id>-<n>`) so staging is the same
/// on every launch.
List<Mesocycle> sampleMesocycles({required DateTime now}) => [
  for (final (prebuilt, id) in [
    ('program-push-pull-legs', sampleMesocycleId),
    ('program-upper-lower', sampleInactiveMesocycleIds[0]),
    ('program-full-body', sampleInactiveMesocycleIds[1]),
  ])
    _copy(prebuilt, id, now.subtract(const Duration(days: 14))),
];

Mesocycle _copy(String prebuiltId, String id, DateTime at) {
  var count = 0;
  return copyMesocycle(
    PrebuiltCatalogue.instance.mesocycles.firstWhere(
      (mesocycle) => mesocycle.id == prebuiltId,
    ),
    authorId: _sampleUserId,
    now: at,
    newId: () => count++ == 0 ? id : '$id-$count',
  );
}

/// The macrocycle following Push/Pull/Legs alone, active since it was
/// started two weeks before [now]; a saved two-block one of the inactive
/// mesocycles, never started; and an older one, ended.
List<Macrocycle> sampleMacrocycles({required DateTime now}) {
  final started = now.subtract(const Duration(days: 14));
  final earlier = now.subtract(const Duration(days: 90));
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
    Macrocycle(
      id: 'sample-macrocycle-winter',
      authorId: _sampleUserId,
      name: 'Winter Block',
      mesocycleIds: sampleInactiveMesocycleIds,
      status: MacrocycleStatus.notStarted,
      mesocycleStartedAt: started,
      dateCreated: started,
      dateModified: started.subtract(const Duration(days: 1)),
    ),
    Macrocycle(
      id: 'sample-macrocycle-summer',
      authorId: _sampleUserId,
      name: 'Summer Base',
      mesocycleIds: [sampleInactiveMesocycleIds[1]],
      status: MacrocycleStatus.ended,
      mesocycleStartedAt: earlier,
      dateCreated: earlier,
      dateModified: started,
    ),
  ];
}
