import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/create_exercise/logic/exercise_draft.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart' show newUuid;

/// Where the create is.
enum ExerciseSaveStatus { reviewing, saving, saved, failed }

/// The last step (Swift `ExerciseSavePresenter`): the review, and Create.
class ExerciseSaveCubit extends Cubit<ExerciseSaveStatus> {
  /// The uid is the signed-in user's, who owns the exercise; without one
  /// nothing is written.
  new({
    required this._draft,
    required this._uid,
    required this._library,
    required this._analytics,
    this._now = DateTime.now,
    this._newId = newUuid,
  }) : super(ExerciseSaveStatus.reviewing);

  static const _screen = 'ExerciseSaveView';

  final ExerciseDraft _draft;
  final String? _uid;
  final TrainingLibraryRepository _library;
  final AnalyticsRepository _analytics;
  final DateTime Function() _now;
  final String Function() _newId;

  void appeared() => _analytics.appear(_screen);

  void disappeared() => _analytics.disappear(_screen);

  /// Stores the exercise between `CreateExercise_Start` and `_Success` or a
  /// severe `_Fail`. A second tap mid-save does nothing.
  Future<void> create() async {
    if (state == ExerciseSaveStatus.saving) return;
    _analytics.analytic('CreateExercise_Start');
    final uid = _uid;
    if (uid == null) {
      _analytics.severe(
        'CreateExercise_Fail',
        'No signed-in user to own the exercise',
      );
      emit(ExerciseSaveStatus.failed);
      return;
    }
    emit(ExerciseSaveStatus.saving);
    try {
      final now = _now();
      await _library.saveUserExercise(
        _draft.toModel(id: _newId(), authorId: uid, now: now),
      );
      _analytics.analytic('CreateExercise_Success');
      emit(ExerciseSaveStatus.saved);
    } on Object catch (error) {
      _analytics.severe('CreateExercise_Fail', error);
      emit(ExerciseSaveStatus.failed);
    }
  }

  /// Back to the review after a failure was shown.
  void failureShown() => emit(ExerciseSaveStatus.reviewing);
}
