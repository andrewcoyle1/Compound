part of 'training_analytics_bloc.dart';

/// Where the sessions have got to.
enum TrainingAnalyticsStatus {
  /// Waiting for the sessions.
  loading,

  /// They have arrived.
  loaded,

  /// They could not be read.
  failure,
}

/// One logged workout, as the Workouts screens list it (Swift
/// `WorkoutEntry`).
typedef WorkoutEntry = ({
  String id,
  DateTime date,
  String name,
  int sets,
  double volumeKg,
});

/// Everything the training analytics screens are built from, as the
/// repositories last gave it, the chart's range and Muscle Balance's
/// selection, and every figure derived from them through
/// `training_analytics.dart` and `compound_maths`.
///
/// ponytail: the figures are recomputed on every read; fine for years of
/// sessions, cache them in the bloc if a screen ever stutters.
final class const TrainingAnalyticsState({
  /// The signed-in user's id.
  required final String uid,

  /// When the screen opened: "today" for every figure.
  required final DateTime now,

  /// The user's sessions; null until they arrive.
  final List<WorkoutSessionModel>? sessions,

  /// The user's own exercises.
  final List<ExerciseModel> userExercises = const [],

  /// The profile, or null until read.
  final UserModel? user,

  /// A chart's range; a week to start, as QuickCharts opens.
  final MetricRange range = MetricRange.week,

  /// The muscle whose trend Muscle Balance shows, if any.
  final Muscles? selectedMuscle,

  /// Whether reading the sessions failed.
  final bool failed = false,
}) extends Equatable {
  /// Where the data has got to.
  TrainingAnalyticsStatus get status => failed
      ? TrainingAnalyticsStatus.failure
      : sessions == null
      ? TrainingAnalyticsStatus.loading
      : TrainingAnalyticsStatus.loaded;

  /// Today, at midnight.
  DateTime get today => DateTime(now.year, now.month, now.day);

  String get _todayKey => dayKeyOf(now.toLocal());

  /// Whether weights show in pounds: the profile's unit, which stands in
  /// for Swift's per-exercise unit (kept on the device, not ported).
  bool get usesPounds =>
      user?.submittedWeightUnitPreference == WeightUnitPreference.pounds;

  /// [kilograms] in the unit shown.
  double inUnit(double kilograms) =>
      usesPounds ? kilograms * AppFormat.poundsPerKilogram : kilograms;

  /// Finished workouts, newest first: rest days, other users' and
  /// future-dated ones aside.
  List<WorkoutSessionModel> get finished =>
      countedSessions(sessions ?? const [], uid: uid, now: now)..sort(
        (a, b) =>
            (b.endedAt ?? b.dateCreated).compareTo(a.endedAt ?? a.dateCreated),
      );

  List<maths.WorkoutSession> get _maths => finished.map(mathsSession).toList();

  /// The user's exercises and the system ones, by name.
  List<ExerciseModel> get library =>
      exerciseLibrary(userExercises, PrebuiltCatalogue.instance.exercises);

  Map<String, Map<maths.Muscle, maths.MuscleTarget>> get _templates =>
      muscleTargets(library);

  // MARK: Exercises

  /// A 1RM card for every exercise.
  List<ExerciseCard> get exerciseCardList => exerciseCards(_maths, library);

  /// The name of exercise [id]: the library's, else as last logged.
  String exerciseName(String id) =>
      library.where((e) => e.id == id).firstOrNull?.name ??
      [
        for (final session in finished)
          for (final exercise in session.exercises)
            if (exercise.templateId == id) exercise.name,
      ].firstOrNull ??
      id;

  /// Exercise [id]'s best estimated 1RM each day it was done, in the unit
  /// shown, oldest first.
  List<MetricPoint> oneRepMaxPoints(String id) => [
    for (final point in oneRepMaxByDay(_maths, id))
      (date: point.date, value: inUnit(point.kg)),
  ];

  // MARK: Muscles

  Map<maths.Muscle, Map<String, double>> get _daily =>
      maths.dailyMuscleSets(_maths, _templates);

  /// Each muscle's sets on each of the last seven days, oldest first.
  Map<Muscles, List<double>> get lastSevenDaysByMuscle {
    final daily = _daily;
    return {
      for (final muscle in Muscles.values)
        muscle: lastSevenDays(daily[mathsMuscle(muscle)], _todayKey),
    };
  }

  /// [muscle]'s sets on each day it was trained, oldest first.
  List<MetricPoint> muscleSetPoints(Muscles muscle) {
    final days = _daily[mathsMuscle(muscle)] ?? const {};
    return [
      for (final day in days.keys.toList()..sort())
        (date: dayOf(day), value: days[day]!),
    ];
  }

  /// The suggestion for [muscle]'s next weeks of sets.
  maths.VolumeSuggestion recommendation(Muscles muscle) =>
      maths.recommendVolume(
        maths.volumeInputs(
          mathsMuscle(muscle),
          sessions: _maths,
          templates: _templates,
          end: now,
          endDay: _todayKey,
          age: ageOn(user?.submittedDateOfBirth, now),
        ),
      );

  /// Each muscle's hard sets in twelve rolling weeks, oldest first, the
  /// last ending today.
  Map<Muscles, List<double>> get weeklySetsByMuscle {
    final weekly = maths.weeklyMuscleSets(_maths, _templates, _todayKey);
    return {
      for (final muscle in Muscles.values) muscle: weekly[mathsMuscle(muscle)]!,
    };
  }

  // MARK: Workouts

  /// Every finished workout, newest first.
  List<WorkoutEntry> get workouts => [
    for (final session in finished)
      (
        id: session.id,
        date: session.endedAt ?? session.dateCreated,
        name: session.name,
        sets: session.loggedSetCount,
        volumeKg: session.loggedVolumeKg,
      ),
  ];

  TrainingAnalyticsState copyWith({
    List<WorkoutSessionModel>? sessions,
    List<ExerciseModel>? userExercises,
    UserModel? Function()? user,
    MetricRange? range,
    Muscles? Function()? selectedMuscle,
    bool? failed,
  }) => TrainingAnalyticsState(
    uid: uid,
    now: now,
    sessions: sessions ?? this.sessions,
    userExercises: userExercises ?? this.userExercises,
    user: user == null ? this.user : user(),
    range: range ?? this.range,
    selectedMuscle: selectedMuscle == null
        ? this.selectedMuscle
        : selectedMuscle(),
    failed: failed ?? this.failed,
  );

  @override
  List<Object?> get props => [
    uid,
    now,
    sessions,
    userExercises,
    user,
    range,
    selectedMuscle,
    failed,
  ];
}
