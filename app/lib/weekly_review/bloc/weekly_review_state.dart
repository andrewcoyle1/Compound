part of 'weekly_review_bloc.dart';

/// Where the review's data has got to.
enum WeeklyReviewStatus {
  /// Waiting for the sessions, meals or weigh-ins.
  loading,

  /// All three have arrived.
  loaded,

  /// One of them could not be read.
  failure,
}

/// Everything the review is built from, as the repositories last gave it,
/// and the week on screen.
final class const WeeklyReviewState({
  /// The signed-in user's id.
  required final String uid,

  /// When the screen opened.
  required final DateTime now,

  /// The first day of the week, 0 for Sunday as `MaterialLocalizations`
  /// counts.
  required final int firstDayOfWeek,

  /// Midnight on the first day of the week on screen.
  required final DateTime weekStart,
  final List<WorkoutSessionModel>? sessions,
  final List<MealLogModel>? meals,
  final List<BodyMeasurementEntry>? measurements,
  final DietPlan? dietPlan,
  final List<ExerciseModel> userExercises = const [],
  final UserModel? user,
  final bool failed = false,
}) extends Equatable {
  /// Where the data has got to.
  WeeklyReviewStatus get status => failed
      ? WeeklyReviewStatus.failure
      : sessions == null || meals == null || measurements == null
      ? WeeklyReviewStatus.loading
      : WeeklyReviewStatus.loaded;

  /// Whether a later week can be shown: not past this one.
  bool get canShowNextWeek =>
      weekStart != WorkoutSessionHighlights.weekStart(now, firstDayOfWeek);

  /// Whether weights show in pounds.
  bool get usesPounds =>
      user?.submittedWeightUnitPreference == WeightUnitPreference.pounds;

  /// The week's review; [muscleName] orders muscles with equal sets.
  WeeklyReview review(String Function(Muscles) muscleName) =>
      WeeklyReview.build(
        sessions: sessions ?? const [],
        measurements: measurements ?? const [],
        meals: meals ?? const [],
        weekStart: weekStart,
        uid: uid,
        goal: weeklySessionGoal(user?.weeklySessionGoal),
        library: exerciseLibrary(
          userExercises,
          PrebuiltCatalogue.instance.exercises,
        ),
        muscleName: muscleName,
        dietPlan: dietPlan,
      );

  WeeklyReviewState copyWith({
    DateTime? weekStart,
    List<WorkoutSessionModel>? sessions,
    List<MealLogModel>? meals,
    List<BodyMeasurementEntry>? measurements,
    DietPlan? Function()? dietPlan,
    List<ExerciseModel>? userExercises,
    UserModel? Function()? user,
    bool? failed,
  }) => WeeklyReviewState(
    uid: uid,
    now: now,
    firstDayOfWeek: firstDayOfWeek,
    weekStart: weekStart ?? this.weekStart,
    sessions: sessions ?? this.sessions,
    meals: meals ?? this.meals,
    measurements: measurements ?? this.measurements,
    dietPlan: dietPlan == null ? this.dietPlan : dietPlan(),
    userExercises: userExercises ?? this.userExercises,
    user: user == null ? this.user : user(),
    failed: failed ?? this.failed,
  );

  @override
  List<Object?> get props => [
    uid,
    now,
    firstDayOfWeek,
    weekStart,
    sessions,
    meals,
    measurements,
    dietPlan,
    userExercises,
    user,
    failed,
  ];
}
