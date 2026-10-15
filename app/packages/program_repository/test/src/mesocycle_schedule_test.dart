// What the parity fixture leaves out: picking the run, local days and the
// macrocycle rules the app's screens use.
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

import '../helpers/contract.dart';

void main() {
  final mesocycle = Mesocycle.fromFirestore(modelFixture('mesocycle', 'full'));
  final macrocycle = Macrocycle.fromFirestore(
    modelFixture('macrocycle', 'full'),
  );
  final now = DateTime.utc(2026, 10, 15, 12);

  group('runFor', () {
    test("follows the macrocycle's current mesocycle", () {
      final current = Macrocycle.fromFirestore({
        ...macrocycle.toFirestore(),
        MacrocycleKeys.mesocycleIds: [mesocycle.id],
        MacrocycleKeys.mesocycleIndex: 0,
        MacrocycleKeys.skips: [
          for (final index in [0, 1])
            CycleSkip(
              mesocycleIndex: index,
              cycleIndex: 0,
              position: 0,
              templateId: 'x',
              date: now,
            ).toFirestore(),
        ],
      });
      final run = MesocycleSchedule.runFor(
        mesocycle,
        macrocycle: current,
        sessions: const [],
      );
      expect(run.startedAt, current.mesocycleStartedAt);
      expect(run.skips, hasLength(1));
      expect(run.firstMicrocycleIndex, current.startMicrocycleIndex);
    });

    test('else follows it as before plans', () {
      for (final other in [null, macrocycle]) {
        final run = MesocycleSchedule.runFor(
          mesocycle,
          macrocycle: other,
          sessions: const [],
        );
        expect(run.startedAt, MesocycleSchedule.epoch);
        expect(run.firstMicrocycleIndex, 0);
      }
    });
  });

  test('sameLocalDay compares local calendar days', () {
    final morning = DateTime(2026, 10, 15, 1);
    expect(sameLocalDay(morning, DateTime(2026, 10, 15, 23)), isTrue);
    expect(sameLocalDay(morning, DateTime(2026, 10, 16, 1)), isFalse);
  });

  test('a scheduled day is completed once a session did it', () {
    final plan = mesocycle.workoutTemplates.first;
    expect(ScheduledDay(dayPlan: plan).isCompleted, isFalse);
    expect(
      ScheduledDay(dayPlan: plan, completedSessionId: 's').isCompleted,
      isTrue,
    );
  });

  group('MacrocycleRules', () {
    test('eventParameters are the Swift ones', () {
      expect(macrocycle.eventParameters, {
        'macrocycle_id': macrocycle.id,
        'macrocycle_mesocycle_count': 2,
        'macrocycle_mesocycle_index': 1,
        'macrocycle_status': macrocycle.status.value,
        'macrocycle_iteration': 2,
      });
    });

    test('skipping records the slot in the current mesocycle', () {
      final slot = ScheduleSlot(
        cycleIndex: 2,
        position: 1,
        dayPlan: mesocycle.workoutTemplates.first,
      );
      final skipped = macrocycle.skipping(slot, now);
      expect(skipped.skips, hasLength(macrocycle.skips.length + 1));
      expect(
        skipped.skips.last.toFirestore(),
        CycleSkip(
          mesocycleIndex: 1,
          cycleIndex: 2,
          position: 1,
          templateId: mesocycle.workoutTemplates.first.workoutId,
          date: now,
        ).toFirestore(),
      );
      expect(skipped.startMicrocycleIndex, macrocycle.startMicrocycleIndex);
      expect(skipped.dateModified, now);
      expect(slot.id, '2-1-${mesocycle.workoutTemplates.first.workoutId}');
    });

    test('an edited, unfollowed macrocycle is only stamped', () {
      final edited = editedMacrocycle(
        macrocycle.copyWith(
          dateModified: now,
          startMicrocycleIndex: 1,
          name: 'Renamed',
        ),
        previous: null,
        now: now,
      );
      expect(edited.name, 'Renamed');
      expect(edited.startMicrocycleIndex, 1);
      expect(edited.mesocycleIndex, macrocycle.mesocycleIndex);
    });
  });
}
