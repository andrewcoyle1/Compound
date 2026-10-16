import 'dart:math';

import 'package:compound_models/compound_models.dart';

/// A random (version 4) UUID in upper case, as Swift's `UUID().uuidString`
/// writes the ids these documents carry.
String newUuid() {
  final random = Random.secure();
  final bytes = [for (var i = 0; i < 16; i++) random.nextInt(256)];
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = [for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0')]
      .join()
      .toUpperCase();
  return [
    hex.substring(0, 8),
    hex.substring(8, 12),
    hex.substring(12, 16),
    hex.substring(16, 20),
    hex.substring(20),
  ].join('-');
}

/// The shipped program matched to how often the user said they exercise
/// (`CreateMesocyclePresenter.recommendedProgramId`): two or fewer sessions
/// a week start on full body, three or four on an upper and lower split,
/// five or more on push/pull/legs. 5/3/1 is never suggested. Null when they
/// have not said.
String? recommendedProgramId(ExerciseFrequency? frequency) =>
    switch (frequency) {
      ExerciseFrequency.never ||
      ExerciseFrequency.oneToTwo => 'program-full-body',
      ExerciseFrequency.threeToFour => 'program-upper-lower',
      ExerciseFrequency.fiveToSix ||
      ExerciseFrequency.daily => 'program-push-pull-legs',
      null => null,
    };

/// The user's own copy of [mesocycle], as `MesocycleManager.copy(of:)` makes
/// it through `SharedItemCopier`: new ids throughout and [authorId] as
/// author, so editing or deleting it never touches the original.
///
/// Every day plan gets a new id, [authorId] and [now] as its dates, and
/// keeps its name, description and picture; its gym is dropped, as Swift
/// drops it. Every exercise slot gets a new id. A system exercise is kept
/// as it is; any other is copied once, with a new id, [authorId] and [now].
/// Set target ids are kept. [newId] makes each id.
Mesocycle copyMesocycle(
  Mesocycle mesocycle, {
  required String authorId,
  required DateTime now,
  String Function() newId = newUuid,
}) => _Copier(
  authorId: authorId,
  now: now,
  newId: newId,
  known: const {},
).mesocycle(mesocycle);

/// What accepting a share saves (`SharedItemCopier.Result`): the
/// recipient's own copy of the payload, and the exercises copied for it,
/// which must be saved first.
final class const SharedItemCopy({
  /// The copy, under the recipient.
  required final SharePayload payload,

  /// The sender's custom exercises, copied as the recipient's.
  required final List<ExerciseModel> newExercises,
}) {
  /// Creates a [SharedItemCopy].
  this;
}

/// The recipient's own copy of a shared [payload]
/// (`SharedItemCopier.copy`): new ids, [recipientId] as author.
///
/// Exercises the recipient can already see (a system one, or one whose id
/// is in [libraryExerciseIds]) keep their id. Any other is the sender's
/// custom exercise, which the recipient cannot write, so it is copied once
/// under a new id and every slot points at the copy. A template keeps its
/// name, description and picture and drops its gym; a mesocycle is copied
/// as [copyMesocycle] copies it.
SharedItemCopy copySharedItem(
  SharePayload payload, {
  required String recipientId,
  required Iterable<String> libraryExerciseIds,
  required DateTime now,
  String Function() newId = newUuid,
}) {
  final copier = _Copier(
    authorId: recipientId,
    now: now,
    newId: newId,
    known: libraryExerciseIds.toSet(),
  );
  final copy = switch (payload) {
    TemplateSharePayload(:final template) => TemplateSharePayload(
      copier.template(template),
    ),
    MesocycleSharePayload(:final mesocycle) => MesocycleSharePayload(
      copier.mesocycle(mesocycle),
    ),
  };
  return SharedItemCopy(
    payload: copy,
    newExercises: copier.copied.values.toList(),
  );
}

class _Copier {
  new({
    required this.authorId,
    required this.now,
    required this.newId,
    required this.known,
  });

  final String authorId;
  final DateTime now;
  final String Function() newId;
  final Set<String> known;
  final copied = <String, ExerciseModel>{};

  ExerciseModel exercise(ExerciseModel exercise) =>
      exercise.isSystemExercise || known.contains(exercise.id)
      ? exercise
      : copied.putIfAbsent(
          exercise.id,
          () => ExerciseModel.fromFirestore({
            ...exercise.toFirestore(),
            ExerciseModelKeys.id: newId(),
            ExerciseModelKeys.authorId: authorId,
            ExerciseModelKeys.dateCreated: now,
            ExerciseModelKeys.dateModified: now,
          }),
        );

  WorkoutTemplateModel template(WorkoutTemplateModel template) =>
      WorkoutTemplateModel(
        workoutId: newId(),
        authorId: authorId,
        name: template.name,
        description: template.description,
        imageUrl: template.imageUrl,
        dateCreated: now,
        dateModified: now,
        exercises: [
          for (final item in template.exercises)
            WorkoutTemplateExercise.fromFirestore({
              ...item.toFirestore(),
              WorkoutTemplateExerciseKeys.id: newId(),
              WorkoutTemplateExerciseKeys.exercise: exercise(item.exercise)
                  .toFirestore(),
            }),
        ],
      );

  Mesocycle mesocycle(Mesocycle mesocycle) => Mesocycle(
    id: newId(),
    authorId: authorId,
    name: mesocycle.name,
    icon: mesocycle.icon,
    colour: mesocycle.colour,
    numMicrocycles: mesocycle.numMicrocycles,
    deload: mesocycle.deload,
    periodisation: mesocycle.periodisation,
    workoutTemplates: [
      for (final day in mesocycle.workoutTemplates) template(day),
    ],
    dateCreated: now,
    dateModified: now,
  );
}
