import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

import '../helpers/contract.dart';

void main() {
  group(InMemoryProgramRepository, () {
    final now = DateTime.utc(2026, 10, 15, 12);
    const sampleUid = 'mock_user_123';

    test("reads each user's own documents only", () async {
      final subject = InMemoryProgramRepository(
        mesocycles: sampleMesocycles(now: now),
        macrocycles: sampleMacrocycles(now: now),
      );

      expect(
        [for (final m in await subject.watchMesocycles(sampleUid).first) m.id],
        [sampleMesocycleId],
      );
      expect(
        [for (final m in await subject.watchMacrocycles(sampleUid).first) m.id],
        ['sample-macrocycle'],
      );
      expect(await subject.watchMesocycles('other').first, isEmpty);
      expect(await subject.watchMacrocycles('other').first, isEmpty);
    });

    test('adds, then merges over, telling watchers each time', () async {
      final subject = InMemoryProgramRepository();
      final mesocycle = Mesocycle.fromFirestore(
        modelFixture('mesocycle', 'full'),
      );
      final macrocycle = Macrocycle.fromFirestore(
        modelFixture('macrocycle', 'full'),
      );
      final uid = mesocycle.authorId;
      final names = subject
          .watchMesocycles(uid)
          .map((mesocycles) => [for (final m in mesocycles) m.name]);
      final statuses = subject
          .watchMacrocycles(uid)
          .map((macrocycles) => [for (final m in macrocycles) m.status]);
      final expectations = [
        expectLater(
          names,
          emitsInOrder([
            <String>[],
            [mesocycle.name],
            ['Renamed'],
          ]),
        ),
        expectLater(statuses, emitsThrough([MacrocycleStatus.ended])),
      ];

      await subject.saveMesocycle(mesocycle);
      await subject.saveMesocycle(
        Mesocycle.fromFirestore({
          ...mesocycle.toFirestore(),
          MesocycleKeys.name: 'Renamed',
        }),
      );
      await subject.saveMacrocycle(macrocycle);
      await subject.saveMacrocycle(
        Macrocycle.fromFirestore({
          ...macrocycle.toFirestore(),
          MacrocycleKeys.status: MacrocycleStatus.ended.value,
        }),
      );
      await Future.wait(expectations);

      expect(
        firestoreToTaggedJson(
          (await subject.watchMesocycles(uid).first).single.toFirestore(),
        ),
        strictlyEquals({
          ...taggedFixture('mesocycle', 'full'),
          'name': 'Renamed',
        }),
      );
    });
  });
}
