import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Where deleting the user's exercise is.
enum DeleteExerciseStatus { idle, deleting, deleted, failed }

/// Deletes the user's own exercise from its detail screen (Swift
/// `ExerciseModelDetailPresenter.deleteExercise`).
class DeleteExerciseCubit extends Cubit<DeleteExerciseStatus> {
  new({required this._library, required this._analytics})
    : super(DeleteExerciseStatus.idle);

  final TrainingLibraryRepository _library;
  final AnalyticsRepository _analytics;

  /// Deletes [exerciseId] between
  /// `ExerciseModelDetailView_DeleteExercise_Start` and `_Success` or a
  /// severe `_Fail`.
  Future<void> delete(String exerciseId) async {
    if (state == DeleteExerciseStatus.deleting) return;
    emit(DeleteExerciseStatus.deleting);
    _analytics.analytic('ExerciseModelDetailView_DeleteExercise_Start');
    try {
      await _library.deleteUserExercise(exerciseId);
      _analytics.analytic('ExerciseModelDetailView_DeleteExercise_Success');
      emit(DeleteExerciseStatus.deleted);
    } on Object catch (error) {
      _analytics.severe('ExerciseModelDetailView_DeleteExercise_Fail', error);
      emit(DeleteExerciseStatus.failed);
    }
  }
}
