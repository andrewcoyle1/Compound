import 'package:compound/programs/programs.dart';
import 'package:compound_models/compound_models.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/helpers.dart';

/// The fixtures' user, who authors [programDays].
const programUid = 'friend';

/// Now in the program tests.
final programNow = DateTime.now();

/// Upper, a rest day, Lower: a three-day microcycle.
final List<WorkoutTemplateModel> programDays = [
  fixtureTemplate(
    'upper',
    name: 'Upper',
    exercises: [fixtureSlot(fixtureLibraryExercise('bench', name: 'Bench'))],
  ),
  fixtureTemplate('rest', name: 'Rest Day'),
  fixtureTemplate(
    'lower',
    name: 'Lower',
    exercises: [fixtureSlot(fixtureLibraryExercise('squat', name: 'Squat'))],
  ),
];

/// A [fixtureMesocycle] of [programDays] run for [cycles] microcycles.
Mesocycle programMesocycle(
  String id, {
  String? name,
  int cycles = 2,
  DeloadType deload = DeloadType.none,
}) {
  final base = fixtureMesocycle(id, programDays, name: name ?? 'Block $id');
  return Mesocycle(
    id: base.id,
    authorId: base.authorId,
    name: base.name,
    icon: base.icon,
    colour: base.colour,
    numMicrocycles: cycles,
    deload: deload,
    workoutTemplates: base.workoutTemplates,
    dateCreated: base.dateCreated,
    dateModified: base.dateModified,
  );
}

/// The macrocycle following [mesocycleIds] from the first, started at the
/// midnight two days before [programNow], so sessions on the previous
/// calendar day fall inside it whatever the hour.
Macrocycle programMacrocycle(
  String id,
  List<String> mesocycleIds, {
  MacrocycleStatus status = MacrocycleStatus.active,
  int index = 0,
}) {
  final started = DateTime(
    programNow.year,
    programNow.month,
    programNow.day - 2,
  );
  return Macrocycle(
    id: id,
    authorId: programUid,
    name: 'Plan $id',
    mesocycleIds: mesocycleIds,
    status: status,
    mesocycleIndex: index,
    mesocycleStartedAt: started,
    dateCreated: started,
    dateModified: started,
  );
}

/// A finished session of [templateId] in mesocycle `m1`.
WorkoutSessionModel programSession(
  String templateId,
  DateTime at, {
  String? id,
  bool rest = false,
}) => WorkoutSessionModel(
  id: id ?? '$templateId-${at.millisecondsSinceEpoch}',
  authorId: programUid,
  name: templateId,
  workoutTemplateId: templateId,
  mesocycleId: 'm1',
  dateCreated: at,
  dateModified: at,
  endedAt: at,
  isRestDay: rest,
  exercises: const [],
);

/// In-memory repositories of one user, and a [ProgramsCubit] over them.
class const ProgramWorld({
  required final InMemoryProgramRepository programs,
  required final InMemoryUserRepository users,
  required final InMemoryWorkoutSessionRepository sessions,
  required final AnalyticsRecorder analytics,
}) {
  /// [mesocycles], [macrocycles] and [sessions] of [programUid], who
  /// follows [active].
  factory seeded({
    List<Mesocycle> mesocycles = const [],
    List<Macrocycle> macrocycles = const [],
    List<WorkoutSessionModel> history = const [],
    String? active,
  }) => ProgramWorld(
    programs: InMemoryProgramRepository(
      mesocycles: mesocycles,
      macrocycles: macrocycles,
    ),
    users: InMemoryUserRepository(
      users: {
        programUid: UserModel.fromFirestore({
          ...sampleUser(now: programNow).toFirestore(),
          UserModelKeys.userId: programUid,
          UserModelKeys.submittedActiveMesocycleId: active,
        }),
      },
    ),
    sessions: InMemoryWorkoutSessionRepository(sessions: history),
    analytics: AnalyticsRecorder(),
  );

  /// A cubit over these repositories, following nobody yet.
  ProgramsCubit cubit({ProgramRepository? programs}) => ProgramsCubit(
    programs: programs ?? this.programs,
    users: users,
    sessions: sessions,
    service: ProgramService(
      programs: programs ?? this.programs,
      users: users,
      sessions: sessions,
    ),
    setup: TrainingSetupService(
      programs: programs ?? this.programs,
      library: InMemoryTrainingLibraryRepository(),
      users: users,
    ),
    analytics: analytics,
  );
}
