import 'package:compound/workout_tracker/logic/set_keypad.dart';
import 'package:compound_models/compound_models.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter/foundation.dart' show protected;
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

/// The set keypad's actions, shared by the live tracker
/// (`ActiveWorkoutCubit`) and the finished-workout editor
/// (`SessionEditCubit`): typing, stepping, bands, chips, Next and ✓. Each
/// cubit supplies where its sets live and how it emits; the edits go
/// through the session controller either way.
mixin KeypadEditing {
  /// The controller the edits go through; null with no session.
  @protected
  ActiveSessionController? get keypadController;

  /// The keypad open now, if any.
  @protected
  SetKeypad? get openKeypadState;

  /// Whether the loading bar shows over the weight keypad.
  @protected
  bool get showsPlatesNow;

  /// Where the plates switch is kept.
  @protected
  DeviceStore get keypadDevice;

  /// The exercise with [exerciseId].
  @protected
  WorkoutExerciseModel? keypadExercise(String exerciseId);

  /// The exercise holding [setId].
  @protected
  WorkoutExerciseModel? keypadExerciseHolding(String setId);

  /// The set with [setId].
  @protected
  WorkoutSetModel? keypadSet(String setId);

  /// [exercise]'s weight unit.
  @protected
  ExerciseWeightUnit keypadUnit(WorkoutExerciseModel exercise);

  /// [exercise]'s distance unit.
  @protected
  DistanceUnit keypadDistanceUnit(WorkoutExerciseModel exercise);

  /// Emits the session as the controller has it; [keypad] replaces the
  /// open keypad. [selection] asks for the selection haptic, where the
  /// screen plays one.
  @protected
  void emitKeypadEdit({SetKeypad? Function()? keypad, bool selection = false});

  /// Emits [showsPlates].
  @protected
  void emitShowsPlates({required bool showsPlates});

  /// Logs [setId] from the keypad's ✓; true when it was refused, so the
  /// keypad stays open.
  @protected
  bool logFromKeypad(String setId);

  /// The set keyboard's `@AppStorage("setKeyboard.showsPlates")`.
  static const showsPlatesKey = 'setKeyboard.showsPlates';

  /// The plates switch as kept on the device; on until switched off.
  @protected
  bool get keptShowsPlates => keypadDevice.getBool(showsPlatesKey) ?? true;

  /// Set when the keypad is put away; the next emit drops it.
  @protected
  bool keypadClosed = false;

  /// Opens the keypad on [field] of [setId].
  void openKeypad(String setId, SetField field) {
    final controller = keypadController;
    final exercise = keypadExerciseHolding(setId);
    final set = keypadSet(setId);
    if (controller == null || exercise == null || set == null) return;
    if (openKeypadState?.setId != setId) controller.commitEdit();
    emitKeypadEdit(
      keypad: () => SetKeypad.open(
        exerciseId: exercise.id,
        set: set,
        field: field,
        fields: SetField.of(set, exercise.trackingMode),
        unit: keypadUnit(exercise),
        distanceUnit: keypadDistanceUnit(exercise),
        isAssisted: controller.weightStep(exercise.id).isAssisted,
      ),
    );
  }

  /// A digit or the decimal point.
  void keypadKey(String key) =>
      _keypadEdit((keypad, set, unit) => keypad.type(key, set, unit));

  /// ⌫.
  void keypadBackspace() =>
      _keypadEdit((keypad, set, unit) => keypad.backspace(set, unit));

  /// − or +: the next weight the equipment makes.
  void keypadStep({required bool up}) {
    final keypad = openKeypadState;
    final controller = keypadController;
    if (keypad == null || controller == null) return;
    final exercise = keypadExercise(keypad.exerciseId);
    final set = keypadSet(keypad.setId);
    if (exercise == null || set == null) return;
    final unit = keypadUnit(exercise).rules;
    final step = controller.weightStep(exercise.id);
    final current = switch (set.weightKg) {
      final kg? => r.convertWeight(kg, unit),
      null => null,
    };
    // Bands alone have no weight to step: ± moves through them one at a
    // time, choosing just that band.
    if (step.kind is r.StepBands) {
      final last = set.bands?.lastOrNull;
      final index = last == null ? -1 : step.bands.indexOf(last);
      final next = step.band(index < 0 ? null : index, forward: up);
      return _keypadSet(
        set.copyWith(
          bands: next == null ? null : [step.bands[next]],
          weightKg: null,
        ),
      );
    }
    final value = up ? step.next(current) : step.previous(current);
    if (value == null) return;
    _keypadSet(set.copyWith(weightKg: r.convertWeightToKg(value, unit)));
  }

  /// ± on an assisted weight: load and assistance swap.
  void keypadSign() =>
      _keypadEdit((keypad, set, unit) => keypad.toggleSign(set, unit));

  /// A weight from the loading bar ("Use 67.5 kg"), in the display unit.
  void keypadWeight(double value) {
    final keypad = openKeypadState;
    final exercise = keypad == null ? null : keypadExercise(keypad.exerciseId);
    final set = keypad == null ? null : keypadSet(keypad.setId);
    if (exercise == null || set == null) return;
    _keypadSet(
      set.copyWith(
        weightKg: r.convertWeightToKg(value, keypadUnit(exercise).rules),
      ),
    );
  }

  /// A band chip: on the set, or off it; the last one off leaves none.
  /// Beside any weight, so a bar with bands keeps both.
  void keypadBand(String name) {
    final keypad = openKeypadState;
    final controller = keypadController;
    final set = keypad == null ? null : keypadSet(keypad.setId);
    if (controller == null || set == null) return;
    final bands = [...?set.bands];
    if (!bands.remove(name)) bands.add(name);
    controller.editSet(set.copyWith(bands: bands.isEmpty ? null : bands));
    emitKeypadEdit(selection: true);
  }

  /// The plates key: the loading bar over the weight keypad shown or put
  /// away, kept on the device for every workout after.
  void togglePlates() {
    final shows = !showsPlatesNow;
    keypadDevice.setBool(showsPlatesKey, value: shows);
    emitShowsPlates(showsPlates: shows);
  }

  /// A reps chip: last set's, the target's least or most.
  void keypadReps(int reps) {
    final keypad = openKeypadState;
    final set = keypad == null ? null : keypadSet(keypad.setId);
    if (set == null) return;
    _keypadSet(set.copyWith(reps: reps));
  }

  /// Reps in reserve, kept as RPE; the chip chosen clears it.
  void keypadRir(int rir) {
    final keypad = openKeypadState;
    final set = keypad == null ? null : keypadSet(keypad.setId);
    if (set == null) return;
    final rpe = r.EffortScale.rpeFromRir(rir);
    final selected = set.rpe == null ? null : r.EffortScale.rirChoice(set.rpe!);
    _keypadSet(set.copyWith(rpe: selected == rir ? null : rpe));
  }

  /// Next →: the row's next field.
  void keypadNext() {
    final keypad = openKeypadState;
    final next = keypad?.nextField;
    final set = keypad == null ? null : keypadSet(keypad.setId);
    final exercise = keypad == null ? null : keypadExercise(keypad.exerciseId);
    if (keypad == null || next == null || set == null || exercise == null) {
      return;
    }
    emitKeypadEdit(keypad: () => keypad.moved(next, set, keypadUnit(exercise)));
  }

  /// ✓ on the row's last field: logs the set and closes; a logged set only
  /// closes, and one that cannot be logged yet stays open.
  void keypadDone() {
    final keypad = openKeypadState;
    final set = keypad == null ? null : keypadSet(keypad.setId);
    if (keypad == null || set == null) return;
    if (set.completedAt == null && logFromKeypad(keypad.setId)) return;
    closeKeypad();
  }

  /// Hides the keypad; the edit carries onto the set's open siblings.
  void closeKeypad() {
    if (openKeypadState == null) return;
    dismissKeypad();
    emitKeypadEdit();
  }

  /// Commits the edit being typed and drops the keypad at the next emit.
  @protected
  void dismissKeypad() {
    keypadController?.commitEdit();
    keypadClosed = true;
  }

  void _keypadEdit(
    (SetKeypad, WorkoutSetModel)? Function(
      SetKeypad keypad,
      WorkoutSetModel set,
      ExerciseWeightUnit unit,
    )
    edit,
  ) {
    final keypad = openKeypadState;
    final controller = keypadController;
    if (keypad == null || controller == null) return;
    final exercise = keypadExercise(keypad.exerciseId);
    final set = keypadSet(keypad.setId);
    if (exercise == null || set == null) return;
    final result = edit(keypad, set, keypadUnit(exercise));
    if (result == null) return;
    controller.editSet(result.$2);
    emitKeypadEdit(keypad: () => result.$1);
  }

  void _keypadSet(WorkoutSetModel set) {
    final keypad = openKeypadState;
    final controller = keypadController;
    final exercise = keypad == null ? null : keypadExercise(keypad.exerciseId);
    if (keypad == null || controller == null || exercise == null) return;
    controller.editSet(set);
    emitKeypadEdit(
      keypad: () => keypad.showing(set, keypadUnit(exercise)),
      selection: true,
    );
  }
}
