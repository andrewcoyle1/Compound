import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Deletes a library workout from its detail screen (Swift
/// `WorkoutTemplateDetailPresenter.deleteWorkout`), once the Undo the screen
/// offered has gone. The screen has closed by then, so this holds no state
/// to show: it writes, records, and rethrows a failure for the snack bar.
class const WorkoutDeleter({
  required final TrainingLibraryRepository library,
  required final AnalyticsRepository analytics,
}) {
  /// Deletes [uid]'s workout [workoutId], between
  /// `WorkoutTemplateDetailView_DeleteWorkout_Start` and `_Success` or a
  /// severe `_Fail`.
  Future<void> delete(String uid, String workoutId) async {
    analytics.analytic('WorkoutTemplateDetailView_DeleteWorkout_Start');
    try {
      await library.deleteWorkoutTemplate(uid, workoutId);
      analytics.analytic('WorkoutTemplateDetailView_DeleteWorkout_Success');
    } on Object catch (error) {
      analytics.severe('WorkoutTemplateDetailView_DeleteWorkout_Fail', error);
      rethrow;
    }
  }
}
