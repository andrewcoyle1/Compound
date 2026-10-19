import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show PrebuiltCatalogue;

import '../helpers/contract.dart';

void main() {
  group('recommendedProgramId', () {
    test('matches the program to how often the user trains', () {
      expect(
        {
          for (final frequency in [null, ...ExerciseFrequency.values])
            frequency: recommendedProgramId(frequency),
        },
        {
          null: null,
          ExerciseFrequency.never: 'program-full-body',
          ExerciseFrequency.oneToTwo: 'program-full-body',
          ExerciseFrequency.threeToFour: 'program-upper-lower',
          ExerciseFrequency.fiveToSix: 'program-push-pull-legs',
          ExerciseFrequency.daily: 'program-push-pull-legs',
        },
      );
    });

    test('names only shipped programs, and never 5/3/1', () {
      final shipped = {
        for (final m in PrebuiltCatalogue.instance.mesocycles) m.id,
      };
      final recommended = {
        for (final f in ExerciseFrequency.values) recommendedProgramId(f)!,
      };
      expect(shipped.containsAll(recommended), isTrue);
      expect(recommended, isNot(contains('program-531')));
    });
  });

  group('copyMesocycle', () {
    final now = DateTime.utc(2026, 10, 15, 9, 30);
    late int count;
    String newId() => 'new-${++count}';

    setUp(() => count = 0);

    test('gives every prebuilt program new ids, owner and dates', () {
      for (final template in PrebuiltCatalogue.instance.mesocycles) {
        final copy = copyMesocycle(
          template,
          authorId: 'user-1',
          now: now,
          newId: newId,
        );

        expect(copy.id, startsWith('new-'));
        expect(copy.authorId, 'user-1');
        expect((copy.dateCreated, copy.dateModified), (now, now));
        expect(
          (
            copy.name,
            copy.icon,
            copy.colour,
            copy.numMicrocycles,
            copy.deload,
            copy.periodisation,
          ),
          (
            template.name,
            template.icon,
            template.colour,
            template.numMicrocycles,
            template.deload,
            template.periodisation,
          ),
        );
        expect(copy.workoutTemplates.length, template.workoutTemplates.length);
        for (final (index, day) in copy.workoutTemplates.indexed) {
          final original = template.workoutTemplates[index];
          expect(day.workoutId, startsWith('new-'));
          expect(day.authorId, 'user-1');
          expect((day.dateCreated, day.dateModified), (now, now));
          expect(day.name, original.name);
          expect(day.description, original.description);
          for (final (slot, item) in day.exercises.indexed) {
            final source = original.exercises[slot];
            expect(item.id, startsWith('new-'));
            // System exercises stay as they are.
            expect(
              firestoreToTaggedJson(item.exercise.toFirestore()),
              firestoreToTaggedJson(source.exercise.toFirestore()),
            );
            expect(
              [for (final t in item.setTargets) t.id],
              [for (final t in source.setTargets) t.id],
            );
          }
        }
        // What is saved is canonical: it decodes and re-encodes to itself.
        final encoded = firestoreToTaggedJson(copy.toFirestore());
        expect(
          firestoreToTaggedJson(
            Mesocycle.fromFirestore(taggedJsonToFirestore(encoded))
                .toFirestore(),
          ),
          strictlyEquals(encoded),
        );
      }
      expect(count, greaterThan(PrebuiltCatalogue.instance.mesocycles.length));
    });

    test('copies a user exercise once, and drops the day gym', () {
      final shared = Mesocycle.fromFirestore(modelFixture('mesocycle', 'full'));
      final exercise = shared.workoutTemplates.first.exercises.first.exercise;
      expect(exercise.isSystemExercise, isFalse);
      final twice = Mesocycle.fromFirestore({
        ...shared.toFirestore(),
        MesocycleKeys.workoutTemplates: [
          for (final day in [
            ...shared.workoutTemplates,
            ...shared.workoutTemplates,
          ])
            day.toFirestore(),
        ],
      });

      final copy = copyMesocycle(
        twice,
        authorId: 'user-1',
        now: now,
        newId: newId,
      );

      final copies = {
        for (final day in copy.workoutTemplates)
          for (final item in day.exercises)
            if (item.exercise.name == exercise.name) item.exercise.id,
      };
      expect(copies, hasLength(1));
      expect(copies.single, startsWith('new-'));
      final copied = copy.workoutTemplates.first.exercises.first.exercise;
      expect(copied.authorId, 'user-1');
      expect((copied.dateCreated, copied.dateModified), (now, now));
      expect(shared.workoutTemplates.first.gymProfileId, isNotNull);
      expect(copy.workoutTemplates.first.gymProfileId, isNull);
      expect(
        copy.workoutTemplates.first.imageUrl,
        shared.workoutTemplates.first.imageUrl,
      );
    });

    test('makes Swift-style ids by default', () {
      final copy = copyMesocycle(
        PrebuiltCatalogue.instance.mesocycles.first,
        authorId: 'user-1',
        now: now,
      );
      expect(copy.id, hasLength(36));
    });
  });

  group('copySharedItem', () {
    final now = DateTime.utc(2026, 10, 15, 9, 30);
    late int count;
    String newId() => 'new-${++count}';

    setUp(() => count = 0);

    final shared = Mesocycle.fromFirestore(modelFixture('mesocycle', 'full'));
    final day = shared.workoutTemplates.first;
    final custom = day.exercises.first.exercise;
    final system = PrebuiltCatalogue
        .instance
        .mesocycles
        .first
        .workoutTemplates
        .first
        .exercises
        .first
        .exercise;
    // Push Day: a system exercise, then the sender's custom one twice.
    final pushDay = WorkoutTemplateModel.fromFirestore({
      ...day.toFirestore(),
      WorkoutTemplateModelKeys.exercises: [
        for (final exercise in [system, custom, custom])
          {
            ...day.exercises.first.toFirestore(),
            WorkoutTemplateExerciseKeys.exercise: exercise.toFirestore(),
          },
      ],
    });

    // MesocycleSharingTests
    // .testAcceptingATemplateCopiesItUnderTheRecipientWithNewIds
    test('copies a template under the recipient, the custom exercise once', () {
      final copy = copySharedItem(
        TemplateSharePayload(pushDay),
        recipientId: 'me',
        libraryExerciseIds: const [],
        now: now,
        newId: newId,
      );
      final template = (copy.payload as TemplateSharePayload).template;
      expect(template.workoutId, startsWith('new-'));
      expect(template.authorId, 'me');
      expect(template.name, pushDay.name);
      expect(pushDay.gymProfileId, isNotNull);
      expect(template.gymProfileId, isNull);
      expect(copy.newExercises, hasLength(1));
      final added = copy.newExercises.single;
      expect(added.id, startsWith('new-'));
      expect(added.authorId, 'me');
      expect(
        [for (final item in template.exercises) item.exercise.id],
        [system.id, added.id, added.id],
      );
      expect(
        [for (final item in template.exercises) item.id]
            .every((id) => id.startsWith('new-')),
        isTrue,
      );
    });

    test("keeps an exercise already in the recipient's library", () {
      final copy = copySharedItem(
        TemplateSharePayload(pushDay),
        recipientId: 'me',
        libraryExerciseIds: [custom.id],
        now: now,
        newId: newId,
      );
      expect(copy.newExercises, isEmpty);
      expect(
        (copy.payload as TemplateSharePayload)
            .template
            .exercises[1]
            .exercise
            .id,
        custom.id,
      );
    });

    // MesocycleSharingTests.testAcceptingAMesocycleCopiesEveryDay
    test('copies a mesocycle, every day under the recipient', () {
      final copy = copySharedItem(
        MesocycleSharePayload(shared),
        recipientId: 'me',
        libraryExerciseIds: const [],
        now: now,
        newId: newId,
      );
      final mesocycle = (copy.payload as MesocycleSharePayload).mesocycle;
      expect(mesocycle.id, startsWith('new-'));
      expect(mesocycle.authorId, 'me');
      expect(
        mesocycle.workoutTemplates,
        hasLength(shared.workoutTemplates.length),
      );
      expect(
        mesocycle.workoutTemplates.every(
          (template) =>
              template.authorId == 'me' &&
              template.workoutId.startsWith('new-'),
        ),
        isTrue,
      );
      expect(copy.newExercises, isNotEmpty);
      expect(
        copy.newExercises.every((exercise) => exercise.authorId == 'me'),
        isTrue,
      );
    });

    test('makes Swift-style ids by default', () {
      final copy = copySharedItem(
        TemplateSharePayload(pushDay),
        recipientId: 'me',
        libraryExerciseIds: const [],
        now: now,
      );
      expect(
        (copy.payload as TemplateSharePayload).template.workoutId,
        hasLength(36),
      );
    });
  });

  group('runningMacrocycle', () {
    Macrocycle macrocycle(String id, MacrocycleStatus status, int day) =>
        Macrocycle(
          id: id,
          authorId: 'user-1',
          name: id,
          mesocycleIds: const ['m'],
          status: status,
          mesocycleStartedAt: DateTime.utc(2026),
          dateCreated: DateTime.utc(2026),
          dateModified: DateTime.utc(2026, 10, day),
        );

    test('is the active or completed one changed last', () {
      expect(runningMacrocycle([]), isNull);
      expect(
        runningMacrocycle([
          macrocycle('ended', MacrocycleStatus.ended, 30),
          macrocycle('not-started', MacrocycleStatus.notStarted, 30),
        ]),
        isNull,
      );
      expect(
        runningMacrocycle([
          macrocycle('old', MacrocycleStatus.active, 1),
          macrocycle('done', MacrocycleStatus.completed, 9),
          macrocycle('ended', MacrocycleStatus.ended, 30),
          macrocycle('older', MacrocycleStatus.active, 2),
        ])?.id,
        'done',
      );
    });

    test('keeps the first on a tie, as Swift max(by:) does', () {
      expect(
        runningMacrocycle([
          macrocycle('first', MacrocycleStatus.active, 5),
          macrocycle('second', MacrocycleStatus.completed, 5),
        ])?.id,
        'first',
      );
    });
  });
}
