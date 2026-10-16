import 'package:compound_models/compound_models.dart' as m;
import 'package:equatable/equatable.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

/// A field of a set's row the keypad types into (`SetKeyboardField`).
enum SetField {
  weight,
  reps,

  /// In metres, with a decimal point.
  distance,

  /// Typed like a microwave: digits fill from the right, so "130" is 1:30.
  duration;

  bool get takesDecimals => this == weight || this == distance;

  /// The fields a row shows, in the order Next walks them: a stretch or hold
  /// after a set is timed, and a hold keeps the set's weight.
  static List<SetField> of(m.WorkoutSetModel set, m.TrackingMode mode) {
    if (rulesSet(set).isTimedPiece) {
      return set.kind == m.SetKind.hold && mode == m.TrackingMode.weightReps
          ? const [weight, duration]
          : const [duration];
    }
    return switch (mode) {
      m.TrackingMode.weightReps => const [weight, reps],
      m.TrackingMode.repsOnly => const [reps],
      m.TrackingMode.timeOnly => const [duration],
      m.TrackingMode.distanceTime => const [distance, duration],
    };
  }
}

/// The keypad open on one field of one set (`SetKeyboardPresenter`'s
/// state). Every key edits the set as it is pressed, so the row behind the
/// keypad always shows what will be logged.
final class const SetKeypad({
  required final String exerciseId,
  required final String setId,
  required final SetField field,
  required final List<SetField> fields,

  /// What the field shows while typed into, with "." as the separator.
  required final String text,

  /// The first key after a field opens replaces its value, as a selected
  /// text field's would.
  final bool replacesOnNextKey = true,

  /// The exercise's weight is assistance, stored negative: the weight
  /// field offers ± (`WeightStep.isAssisted`).
  final bool isAssisted = false,
}) extends Equatable {
  /// Opens [field] on [set], showing its stored value.
  factory open({
    required String exerciseId,
    required m.WorkoutSetModel set,
    required SetField field,
    required List<SetField> fields,
    required m.ExerciseWeightUnit unit,
    bool isAssisted = false,
  }) => SetKeypad(
    exerciseId: exerciseId,
    setId: set.id,
    field: field,
    fields: fields,
    text: valueText(field, set, unit),
    isAssisted: isAssisted,
  );

  /// The ± key, on an assisted exercise's weight only.
  bool get showsSignKey => field == SetField.weight && isAssisted;

  /// The field after this one: weight → reps, distance → time.
  SetField? get nextField {
    final index = fields.indexOf(field);
    return index >= 0 && index + 1 < fields.length ? fields[index + 1] : null;
  }

  /// The same set on [next], showing its value.
  SetKeypad moved(
    SetField next,
    m.WorkoutSetModel set,
    m.ExerciseWeightUnit unit,
  ) => SetKeypad(
    exerciseId: exerciseId,
    setId: setId,
    field: next,
    fields: fields,
    text: valueText(next, set, unit),
    isAssisted: isAssisted,
  );

  /// [key] ("0"–"9" or ".") typed into [set]: the keypad and the set it
  /// makes, or `null` when the key is refused (too long, a second point).
  (SetKeypad, m.WorkoutSetModel)? type(
    String key,
    m.WorkoutSetModel set,
    m.ExerciseWeightUnit unit,
  ) {
    // Assistance stays assistance: typing over "-30" types another
    // negative weight.
    final base = replacesOnNextKey
        ? (showsSignKey && text.startsWith('-') ? '-' : '')
        : text;
    final String candidate;
    if (key == '-' && showsSignKey) {
      return toggleSign(set, unit);
    } else if (key == '.' || key == ',') {
      if (!field.takesDecimals || base.contains('.')) return null;
      candidate = '${base.isEmpty || base == '-' ? '${base}0' : base}.';
    } else if (RegExp(r'^\d$').hasMatch(key)) {
      candidate = base + key;
    } else {
      return null;
    }
    if (!_fits(candidate)) return null;
    final updated = commit(candidate, set, unit);
    if (updated == null) return null;
    return (_withText(candidate), updated);
  }

  /// The last character off, or the whole value just opened.
  (SetKeypad, m.WorkoutSetModel)? backspace(
    m.WorkoutSetModel set,
    m.ExerciseWeightUnit unit,
  ) {
    final candidate = replacesOnNextKey || text.isEmpty
        ? ''
        : text.substring(0, text.length - 1);
    final updated = commit(candidate, set, unit);
    if (updated == null) return null;
    return (_withText(candidate), updated);
  }

  /// ±: flips the weight between load and assistance, 30 kg to −30 kg. On
  /// an empty field it starts a negative number, or cancels one just
  /// started, so "± 3 0" types −30. `null` off an assisted weight.
  (SetKeypad, m.WorkoutSetModel)? toggleSign(
    m.WorkoutSetModel set,
    m.ExerciseWeightUnit unit,
  ) {
    if (!showsSignKey) return null;
    final weightKg = set.weightKg;
    if (weightKg != null && weightKg != 0) {
      final flipped = set.copyWith(weightKg: -weightKg);
      return (showing(flipped, unit), flipped);
    }
    return (_withText(text == '-' ? '' : '-'), set.copyWith(weightKg: null));
  }

  /// The field showing [set]'s value again, as after a step or a chip.
  SetKeypad showing(m.WorkoutSetModel set, m.ExerciseWeightUnit unit) =>
      SetKeypad(
        exerciseId: exerciseId,
        setId: setId,
        field: field,
        fields: fields,
        text: valueText(field, set, unit),
        isAssisted: isAssisted,
      );

  /// The weight the field shows, in [unit] and as the total the bar
  /// carries (any machine base back on), read from the typed text while the
  /// weight is open. Where the field shows the stored weight the stored one
  /// is read, so + on a 44.092 lb bar, shown as "224.09", is still the
  /// 224.092 the bar makes.
  double? shownWeight(m.WorkoutSetModel set, m.ExerciseWeightUnit unit) {
    final kg = set.weightKg;
    final stored = kg == null
        ? null
        : (r.convertWeight(kg, unit.rules) * 1000).roundToDouble() / 1000;
    if (field != SetField.weight) return stored;
    final base = r.convertWeight(set.machineBaseKg ?? 0, unit.rules);
    if (stored != null && formatNumber(stored - base) == text) return stored;
    final typed = double.tryParse(text);
    return typed == null ? null : typed + base;
  }

  SetKeypad _withText(String text) => SetKeypad(
    exerciseId: exerciseId,
    setId: setId,
    field: field,
    fields: fields,
    text: text,
    replacesOnNextKey: false,
    isAssisted: isAssisted,
  );

  bool _fits(String candidate) => switch (field) {
    SetField.reps => candidate.length <= 3,
    // mmss: up to 99:99.
    SetField.duration => candidate.length <= 4,
    SetField.weight || SetField.distance => () {
      final parts = candidate.split('.');
      final whole = field == SetField.distance ? 5 : 4;
      return parts.first.replaceAll('-', '').length <= whole &&
          (parts.length < 2 || parts[1].length <= 2);
    }(),
  };

  /// [text] written into [set]'s field; `null` when a logged set would be
  /// left with no reps (cleared, it would read as a single everywhere).
  m.WorkoutSetModel? commit(
    String text,
    m.WorkoutSetModel set,
    m.ExerciseWeightUnit unit,
  ) {
    switch (field) {
      case SetField.weight:
        final typed = double.tryParse(text);
        // Typed as the load: a machine base kept out of it goes back on.
        return set.copyWith(
          weightKg: typed == null
              ? null
              : r.convertWeightToKg(typed, unit.rules) +
                    (set.machineBaseKg ?? 0),
        );
      case SetField.reps:
        final typed = int.tryParse(text);
        if (set.completedAt != null && (typed ?? 0) < 1) return null;
        return set.copyWith(reps: typed);
      case SetField.distance:
        return set.copyWith(distanceMeters: double.tryParse(text));
      case SetField.duration:
        return set.copyWith(durationSec: secondsFromDigits(text));
    }
  }

  /// What typing starts from: the stored value as the keys would enter it.
  static String valueText(
    SetField field,
    m.WorkoutSetModel set,
    m.ExerciseWeightUnit unit,
  ) => switch (field) {
    SetField.weight => switch (loadKg(set)) {
      final kg? => formatNumber(r.convertWeight(kg, unit.rules)),
      null => '',
    },
    SetField.reps => set.reps?.toString() ?? '',
    SetField.distance => switch (set.distanceMeters) {
      final meters? => formatNumber(meters),
      null => '',
    },
    SetField.duration => switch (set.durationSec) {
      final seconds? => digitsFromSeconds(seconds),
      null => '',
    },
  };

  /// The weight as typed: without any machine base.
  static double? loadKg(m.WorkoutSetModel set) => switch (set.weightKg) {
    final kg? => kg - (set.machineBaseKg ?? 0),
    null => null,
  };

  /// Up to two decimals, trailing zeros dropped: "102.5", "60".
  static String formatNumber(double value) {
    final fixed = ((value * 100).roundToDouble() / 100).toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  /// "130" → 90, "45" → 45, "" → null.
  static int? secondsFromDigits(String digits) {
    final value = int.tryParse(digits);
    if (value == null) return null;
    return (value ~/ 100) * 60 + value % 100;
  }

  /// 90 → "130", the digits that type a duration back in.
  static String digitsFromSeconds(int seconds) =>
      '${(seconds ~/ 60) * 100 + seconds % 60}';

  /// The typed digits as a clock: "1" → "0:01", "130" → "1:30".
  static String clockFromDigits(String digits) {
    final padded = digits.padLeft(3, '0');
    return '${int.parse(padded.substring(0, padded.length - 2))}:'
        '${padded.substring(padded.length - 2)}';
  }

  @override
  List<Object?> get props => [
    exerciseId,
    setId,
    field,
    fields,
    text,
    replacesOnNextKey,
    isAssisted,
  ];
}
