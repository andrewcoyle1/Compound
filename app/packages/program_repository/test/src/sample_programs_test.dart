import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);

  test("staging's profile names the sample program and gym", () {
    final user = sampleUser(now: now);
    final mesocycle = sampleMesocycles(now: now).single;
    final macrocycle = sampleMacrocycles(now: now).single;

    expect(user.submittedActiveMesocycleId, sampleMesocycleId);
    expect(mesocycle.id, sampleMesocycleId);
    expect(mesocycle.authorId, user.userId);
    expect(macrocycle.authorId, user.userId);
    expect(macrocycle.mesocycleIds, [sampleMesocycleId]);
    expect(macrocycle.name, mesocycle.name);
    expect(runningMacrocycle([macrocycle]), same(macrocycle));
    expect(user.submittedFavouriteGymProfileId, sampleGymProfiles.single.id);
    expect(sampleGymProfiles.single.authorId, user.userId);
  });

  test('the sample program is the one recommended to its user', () {
    final user = sampleUser(now: now);
    final mesocycle = sampleMesocycles(now: now).single;
    final recommended = PrebuiltCatalogue.instance.mesocycles.firstWhere(
      (m) => m.id == recommendedProgramId(user.submittedExerciseFrequency),
    );

    expect(mesocycle.name, recommended.name);
    expect(
      mesocycle.workoutTemplates.length,
      recommended.workoutTemplates.length,
    );
    final ids = {
      mesocycle.id,
      for (final day in mesocycle.workoutTemplates) day.workoutId,
      for (final day in mesocycle.workoutTemplates)
        for (final item in day.exercises) item.id,
    };
    expect(ids.every((id) => id.startsWith(sampleMesocycleId)), isTrue);
    expect(
      sampleMesocycles(now: now).single.workoutTemplates.first.workoutId,
      mesocycle.workoutTemplates.first.workoutId,
    );
  });
}
