import 'package:compound_models/compound_models.dart';
import 'package:program_repository/src/program_rules.dart';

/// The colours a mesocycle can be drawn in, as stored: Swift's
/// `MesocycleIconPresenter.defaultColours` (primary, red, orange, yellow,
/// green, blue, purple) as `asHex()` writes them in light mode.
const mesocycleColours = [
  '#000000',
  '#FF3B30',
  '#FF9500',
  '#FFCC00',
  '#34C759',
  '#007AFF',
  '#AF52DE',
];

/// The SF Symbols a mesocycle can show (`MesocycleIconPresenter
/// .defaultIcons`).
const mesocycleIcons = [
  'flag.pattern.checkered',
  'arcade.stick',
  'gamecontroller',
  'figure.walk',
  'airplane.up.right',
  'sailboat.fill',
  'gauge.with.dots.needle.bottom.100percent',
];

/// The names a mesocycle's days are given until the user names one, in
/// the user's language: "Rest Day", and "Workout A" for a letter.
class const DayNameLabels({
  /// "Rest Day".
  required final String restDay,

  /// "Workout A" for the letter "A".
  required final String Function(String letter) workout,
}) {
  /// Creates [DayNameLabels].
  this;
}

/// A new mesocycle of one rest day named "Rest", eight microcycles and no
/// deload, as Swift's `Mesocycle(id:authorId:name:icon:colour:)` makes it.
Mesocycle newMesocycle({
  required String id,
  required String authorId,
  required String name,
  required String icon,
  required String colour,
  required DateTime now,
  String Function() newId = newUuid,
}) => Mesocycle(
  id: id,
  authorId: authorId,
  name: name,
  icon: icon,
  colour: colour,
  workoutTemplates: [_day(newId(), authorId, 'Rest', now)],
  dateCreated: now,
  dateModified: now,
);

WorkoutTemplateModel _day(
  String id,
  String authorId,
  String name,
  DateTime now,
) => WorkoutTemplateModel(
  workoutId: id,
  authorId: authorId,
  name: name,
  dateCreated: now,
  dateModified: now,
  exercises: const [],
);

/// [mesocycle] with the given fields changed.
Mesocycle editedMesocycle(
  Mesocycle mesocycle, {
  String? name,
  String? icon,
  String? colour,
  int? numMicrocycles,
  DeloadType? deload,
  bool? periodisation,
  List<WorkoutTemplateModel>? workoutTemplates,
}) => Mesocycle(
  id: mesocycle.id,
  authorId: mesocycle.authorId,
  name: name ?? mesocycle.name,
  icon: icon ?? mesocycle.icon,
  colour: colour ?? mesocycle.colour,
  numMicrocycles: numMicrocycles ?? mesocycle.numMicrocycles,
  deload: deload ?? mesocycle.deload,
  periodisation: periodisation ?? mesocycle.periodisation,
  workoutTemplates: workoutTemplates ?? mesocycle.workoutTemplates,
  dateCreated: mesocycle.dateCreated,
  dateModified: mesocycle.dateModified,
);

WorkoutTemplateModel _renamed(WorkoutTemplateModel day, String name) =>
    WorkoutTemplateModel.fromFirestore({
      ...day.toFirestore(),
      WorkoutTemplateModelKeys.name: name,
    });

/// A, B … Z, then A1, B1 … for the workout at [index] from 0
/// (`letterForWorkoutIndex`).
String workoutLetter(int index) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  if (index < 0) return 'A';
  if (index < alphabet.length) return alphabet[index];
  return '${alphabet[index % alphabet.length]}${index ~/ alphabet.length}';
}

/// [mesocycle] with every day still on a generated name renamed for what
/// it now is: a rest day "Rest Day", a workout "Workout A", "Workout B" in
/// order, rest days taking no letter. A name the user typed is kept
/// (`recalculateAutoWorkoutTemplateModelNames`).
Mesocycle withDayNames(Mesocycle mesocycle, DayNameLabels labels) {
  final days = mesocycle.workoutTemplates;
  var workouts = 0;
  return editedMesocycle(
    mesocycle,
    workoutTemplates: [
      for (final day in days)
        switch (day.exercises.isEmpty
            ? labels.restDay
            : labels.workout(workoutLetter(workouts++))) {
          final name when _isGeneratedName(day.name, days.length, labels) =>
            _renamed(day, name),
          _ => day,
        },
    ],
  );
}

/// Whether [name] is one the screen made rather than the user: the rest
/// names in English too (mesocycles saved before the names were
/// localised), "Workout" and one letter, or a lettered workout name.
bool _isGeneratedName(String name, int dayCount, DayNameLabels labels) {
  final trimmed = name.trim();
  if (['Rest', 'Rest Day', labels.restDay].contains(trimmed)) return true;
  if (trimmed.startsWith('Workout ') &&
      RegExp(r'^\p{L}$', unicode: true).hasMatch(trimmed.split(' ').last)) {
    return true;
  }
  for (var index = 0; index <= dayCount; index++) {
    if (trimmed == labels.workout(workoutLetter(index))) return true;
  }
  return false;
}

/// [mesocycle] with a rest day appended, the days renamed to fit
/// (`onAddDayPressed`).
Mesocycle addingDay(
  Mesocycle mesocycle, {
  required String id,
  required DateTime now,
  required DayNameLabels labels,
}) => withDayNames(
  editedMesocycle(
    mesocycle,
    workoutTemplates: [
      ...mesocycle.workoutTemplates,
      _day(id, mesocycle.authorId, labels.restDay, now),
    ],
  ),
  labels,
);

/// [mesocycle] without the day [dayId], the days renamed to fit. The last
/// day is never removed (`onRemoveWorkoutTemplateModelPressed`).
Mesocycle removingDay(
  Mesocycle mesocycle,
  String dayId, {
  required DayNameLabels labels,
}) {
  final days = mesocycle.workoutTemplates;
  if (days.length <= 1) return mesocycle;
  return withDayNames(
    editedMesocycle(
      mesocycle,
      workoutTemplates: [
        for (final day in days)
          if (day.workoutId != dayId) day,
      ],
    ),
    labels,
  );
}

/// [mesocycle] with the day [dayId] named [name].
Mesocycle renamingDay(Mesocycle mesocycle, String dayId, String name) =>
    editedMesocycle(
      mesocycle,
      workoutTemplates: [
        for (final day in mesocycle.workoutTemplates)
          if (day.workoutId == dayId) _renamed(day, name) else day,
      ],
    );

/// Whether [mesocycle] has a workout to train: one of rest days alone has
/// nothing to activate or save.
bool hasWorkoutDay(Mesocycle mesocycle) =>
    mesocycle.workoutTemplates.any((day) => day.exercises.isNotEmpty);

/// Whether [current] differs from [initial] in anything the editor
/// changes (`MesocycleDesignPresenter.hasUnsavedChanges`).
bool hasUnsavedMesocycleChanges(Mesocycle initial, Mesocycle current) =>
    !_same(initial.toFirestore(), current.toFirestore());

bool _same(Object? a, Object? b) => switch ((a, b)) {
  (final Map<String, Object?> a, final Map<String, Object?> b) =>
    a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key])),
  (final List<Object?> a, final List<Object?> b) =>
    a.length == b.length &&
        [for (var i = 0; i < a.length; i++) i].every((i) => _same(a[i], b[i])),
  _ => a == b,
};
