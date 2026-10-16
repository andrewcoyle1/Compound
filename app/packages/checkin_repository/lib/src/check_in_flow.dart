/// The weekly check-in's decisions, ported from the pure parts of the Swift
/// `CheckInPresenter`: the week under review, which steps to show, and what
/// each list step saves.
library;

import 'package:checkin_repository/src/expenditure_inputs.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:compound_models/compound_models.dart';

/// The check-in's modules, in the order the Strategy settings screen names
/// them (`CheckInStep`). [name] is the analytics name.
enum CheckInStep {
  /// "Your Week".
  introduction,

  /// Which days were partly logged.
  partialLogging,

  /// A weigh-in, when none is recent.
  weighIn,

  /// Which unlogged days were fasts.
  fasting,

  /// Start or end a logging break.
  loggingBreak,

  /// The target proposal, or why the target stays.
  programUpdate,
}

/// One reviewed day (`CheckInDayRow`): its logged intake, null when nothing
/// was logged, and the row's toggle.
class const CheckInDay({
  required final String dayKey,
  required final double? intakeKcal,
  required final bool isOn,
}) {
  /// Creates a [CheckInDay].
  this;

  /// Anything was logged, even zero calories.
  bool get isLogged => intakeKcal != null;

  /// This row with its toggle set to [on].
  CheckInDay toggled({required bool on}) =>
      CheckInDay(dayKey: dayKey, intakeKcal: intakeKcal, isOn: on);
}

/// The check-in flow, computed once when it starts (`CheckInPresenter`'s
/// `buildWeek` and `buildSteps`).
class CheckInFlow {
  /// Builds the flow at [now] from the repositories' data: [meals] as
  /// `watchMeals` emits them, and [expenditureKcal], the current estimate,
  /// which a fast check-in compares each day's intake against.
  new({
    required DateTime now,
    required this.settings,
    required double expenditureKcal,
    List<MealLogModel> meals = const [],
    List<NutritionDayAnnotation> annotations = const [],
    this._measurements = const [],
    this.openLoggingBreak,
  }) : _annotations = {for (final a in annotations) a.dayKey: a},
       _today = localDayKey(now) {
    final yesterday = maths.addDays(_today, -1);
    weekDays = [
      for (var offset = 6; offset >= 0; offset--)
        () {
          final dayKey = maths.addDays(yesterday, -offset);
          final logged = [
            for (final meal in meals)
              if (meal.dayKey == dayKey) meal,
          ];
          return CheckInDay(
            dayKey: dayKey,
            intakeKcal: logged.isEmpty
                ? null
                : logged
                      .expand((meal) => meal.items)
                      .fold<double>(
                        0,
                        (sum, item) =>
                            sum +
                            (item.nutrients.values[NutrientKey.calories] ?? 0),
                      ),
            isOn: _annotations[dayKey]?.isPartiallyLogged ?? false,
          );
        }(),
    ];
    final threshold =
        expenditureKcal * maths.ExpenditureConstants.partialDayFraction;
    partialRows = settings.fastCheckIn
        ? [
            for (final day in weekDays)
              if (day.intakeKcal case final intake? when intake < threshold)
                day,
          ]
        : weekDays;
    fastingRows = [
      for (final day in weekDays)
        if (!day.isLogged)
          day.toggled(on: _annotations[day.dayKey]?.isFastingDay ?? false),
    ];
    steps = [
      if (!settings.fastCheckIn) CheckInStep.introduction,
      if (settings.partialLoggingEnabled &&
          weekDays.any((day) => day.isLogged) &&
          partialRows.isNotEmpty)
        CheckInStep.partialLogging,
      if (settings.weighInEnabled && !hasRecentWeighIn) CheckInStep.weighIn,
      if (settings.fastingEnabled && fastingRows.isNotEmpty)
        CheckInStep.fasting,
      if (settings.loggingBreakEnabled) CheckInStep.loggingBreak,
      CheckInStep.programUpdate,
    ];
  }

  /// How stale a weigh-in may be before the check-in asks for one
  /// (`CheckInPresenter.weighInRecencyDays`).
  static const weighInRecencyDays = 3;

  /// The user's strategy settings.
  final NutritionStrategySettings settings;

  /// The break open now, which the logging-break step offers to end.
  final LoggingBreak? openLoggingBreak;

  final Map<String, NutritionDayAnnotation> _annotations;
  final List<BodyMeasurementEntry> _measurements;
  final String _today;

  /// The seven days ending yesterday, oldest first, toggled on when already
  /// annotated as partly logged.
  late final List<CheckInDay> weekDays;

  /// The partial-logging step's rows: the whole week, or in a fast check-in
  /// only the logged days under half the estimate.
  late final List<CheckInDay> partialRows;

  /// The fasting step's rows: the days with nothing logged, toggled on when
  /// already annotated as fasts.
  late final List<CheckInDay> fastingRows;

  /// The steps to show, each only when its setting is on and it has
  /// something to ask.
  late final List<CheckInStep> steps;

  Iterable<BodyMeasurementEntry> get _weighIns => _measurements.where(
    (entry) => entry.deletedAt == null && entry.weightKg != null,
  );

  /// A weigh-in since local midnight [weighInRecencyDays] days ago.
  bool get hasRecentWeighIn {
    final cutoff = localMidnight(maths.addDays(_today, -weighInRecencyDays));
    return _weighIns.any((entry) => !entry.date.isBefore(cutoff));
  }

  /// The reviewed days with anything logged.
  int get loggedDayCount => weekDays.where((day) => day.isLogged).length;

  /// The weigh-ins during the reviewed days.
  int get weighInCount {
    final start = localMidnight(weekDays.first.dayKey);
    final end = localMidnight(_today);
    return _weighIns
        .where(
          (entry) => !entry.date.isBefore(start) && entry.date.isBefore(end),
        )
        .length;
  }

  /// What the partial-logging step saves from [rows]: each day's
  /// `isPartiallyLogged` set from its toggle, its fasting flag kept.
  List<NutritionDayAnnotation> partialAnnotations(
    List<CheckInDay> rows, {
    required String uid,
    required DateTime now,
  }) => [
    for (final row in rows)
      _annotation(row.dayKey, uid: uid, now: now, partial: row.isOn),
  ];

  /// What the fasting step saves from [rows]: each day's `isFastingDay` set
  /// from its toggle, its partial flag kept.
  List<NutritionDayAnnotation> fastingAnnotations(
    List<CheckInDay> rows, {
    required String uid,
    required DateTime now,
  }) => [
    for (final row in rows)
      _annotation(row.dayKey, uid: uid, now: now, fasting: row.isOn),
  ];

  /// One day's annotation with only the flag the step owns changed, so one
  /// step never wipes the other's answer.
  NutritionDayAnnotation _annotation(
    String dayKey, {
    required String uid,
    required DateTime now,
    bool? partial,
    bool? fasting,
  }) {
    final existing = _annotations[dayKey];
    return NutritionDayAnnotation(
      dayKey: dayKey,
      authorId: existing?.authorId ?? uid,
      dateModified: now,
      isPartiallyLogged: partial ?? existing?.isPartiallyLogged ?? false,
      isFastingDay: fasting ?? existing?.isFastingDay ?? false,
    );
  }
}
