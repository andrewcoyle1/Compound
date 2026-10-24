import 'package:coach_repository/coach_repository.dart';
import 'package:compound/l10n/l10n.dart';

/// The coach's words for the app's terms.
extension CoachWords on AppLocalizations {
  /// The questions offered before the first message
  /// (`CoachContext.suggestedQuestions`).
  List<String> coachSuggestions(CoachContextKind kind) => switch (kind) {
    CoachContextKind.today => [coachAskToday1, coachAskToday2, coachAskToday3],
    CoachContextKind.weightTrend => [
      coachAskWeightTrend1,
      coachAskWeightTrend2,
      coachAskWeightTrend3,
    ],
    CoachContextKind.exercise => [
      coachAskExercise1,
      coachAskExercise2,
      coachAskExercise3,
    ],
    CoachContextKind.session => [
      coachAskSession1,
      coachAskSession2,
      coachAskSession3,
    ],
    CoachContextKind.checkIn => [
      coachAskCheckIn1,
      coachAskCheckIn2,
      coachAskCheckIn3,
    ],
    CoachContextKind.nutritionDay => [
      coachAskNutritionDay1,
      coachAskNutritionDay2,
      coachAskNutritionDay3,
    ],
    CoachContextKind.weeklyReview => [
      coachAskWeeklyReview1,
      coachAskWeeklyReview2,
      coachAskWeeklyReview3,
    ],
    CoachContextKind.mesocycle => [
      coachAskMesocycle1,
      coachAskMesocycle2,
      coachAskMesocycle3,
    ],
    CoachContextKind.expenditure => [
      coachAskExpenditure1,
      coachAskExpenditure2,
      coachAskExpenditure3,
    ],
    CoachContextKind.muscleGroup => [
      coachAskMuscleGroup1,
      coachAskMuscleGroup2,
      coachAskMuscleGroup3,
    ],
  };

  /// Why the coach could not answer (`CoachError.errorDescription`).
  String coachFailure(CoachFailure failure) => switch (failure) {
    CoachFailure.consentRequired => coachErrorConsent,
    CoachFailure.premiumRequired => coachErrorPremium,
    CoachFailure.dailyLimitReached => coachErrorDailyLimit,
    CoachFailure.tooManyAtOnce => coachErrorTooManyAtOnce,
    CoachFailure.unavailable => coachErrorUnavailable,
    CoachFailure.failed => coachErrorFailed,
  };

  /// What the coach is doing while it runs [tool] (`coachChat`'s ten data
  /// tools), grouped by what they read; "Thinking" for none or a tool this
  /// build does not know.
  String coachReading(String? tool) => switch (tool) {
    'get_profile_and_targets' => coachReadingProfile,
    'get_workout_history' => coachReadingWorkouts,
    'get_exercise_progress' => coachReadingExercise,
    'get_training_volume' => coachReadingVolume,
    'get_nutrition' => coachReadingNutrition,
    'get_body_metrics' => coachReadingBody,
    'get_expenditure' => coachReadingExpenditure,
    'get_steps' => coachReadingSteps,
    'get_plan' => coachReadingPlan,
    'get_check_ins' => coachReadingCheckIns,
    _ => coachThinking,
  };
}
