import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Deletes the user's own exercise from its detail screen (Swift
/// `ExerciseModelDetailPresenter.deleteExercise`), once the Undo the screen
/// offered has gone. The screen has closed by then, so this holds no state
/// to show: it writes, records, and rethrows a failure for the snack bar.
class const ExerciseDeleter({
  required final TrainingLibraryRepository library,
  required final AnalyticsRepository analytics,
}) {
  /// Deletes [exerciseId] between
  /// `ExerciseModelDetailView_DeleteExercise_Start` and `_Success` or a
  /// severe `_Fail`.
  Future<void> delete(String exerciseId) async {
    analytics.analytic('ExerciseModelDetailView_DeleteExercise_Start');
    try {
      await library.deleteUserExercise(exerciseId);
      analytics.analytic('ExerciseModelDetailView_DeleteExercise_Success');
    } on Object catch (error) {
      analytics.severe('ExerciseModelDetailView_DeleteExercise_Fail', error);
      rethrow;
    }
  }
}
