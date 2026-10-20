import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Where deleting a library workout is.
enum DeleteWorkoutStatus { idle, deleting, deleted, failed }

/// Deletes a library workout from its detail screen (Swift
/// `WorkoutTemplateDetailPresenter.deleteWorkout`).
class DeleteWorkoutCubit extends Cubit<DeleteWorkoutStatus> {
  new({required this._library, required this._analytics})
    : super(DeleteWorkoutStatus.idle);

  final TrainingLibraryRepository _library;
  final AnalyticsRepository _analytics;

  /// Deletes [uid]'s workout [workoutId], between
  /// `WorkoutTemplateDetailView_DeleteWorkout_Start` and `_Success` or a
  /// severe `_Fail`.
  Future<void> delete(String uid, String workoutId) async {
    if (state == DeleteWorkoutStatus.deleting) return;
    emit(DeleteWorkoutStatus.deleting);
    _analytics.analytic('WorkoutTemplateDetailView_DeleteWorkout_Start');
    try {
      await _library.deleteWorkoutTemplate(uid, workoutId);
      _analytics.analytic('WorkoutTemplateDetailView_DeleteWorkout_Success');
      emit(DeleteWorkoutStatus.deleted);
    } on Object catch (error) {
      _analytics.severe('WorkoutTemplateDetailView_DeleteWorkout_Fail', error);
      emit(DeleteWorkoutStatus.failed);
    }
  }
}
