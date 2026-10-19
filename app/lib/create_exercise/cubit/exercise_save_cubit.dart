import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/create_exercise/logic/exercise_draft.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart' show newDocumentId;
import 'package:equatable/equatable.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Where the create is.
enum ExerciseSaveStatus { reviewing, saving, saved, failed }

/// Where the create is, and once saved the exercise, for a picker to tick.
final class const ExerciseSaveState({
  final ExerciseSaveStatus status = ExerciseSaveStatus.reviewing,
  final ExerciseModel? created,
}) extends Equatable {
  @override
  List<Object?> get props => [status, created];
}

/// The last step (Swift `ExerciseSavePresenter`): the review, and Create.
class ExerciseSaveCubit extends Cubit<ExerciseSaveState> {
  /// The uid is the signed-in user's, who owns the exercise; without one
  /// nothing is written.
  new({
    required this._draft,
    required this._uid,
    required this._library,
    required this._analytics,
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : super(const ExerciseSaveState());

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
    if (state.status == ExerciseSaveStatus.saving) return;
    _analytics.analytic('CreateExercise_Start');
    final uid = _uid;
    if (uid == null) {
      _analytics.severe(
        'CreateExercise_Fail',
        'No signed-in user to own the exercise',
      );
      emit(const ExerciseSaveState(status: ExerciseSaveStatus.failed));
      return;
    }
    emit(const ExerciseSaveState(status: ExerciseSaveStatus.saving));
    try {
      final exercise = _draft.toModel(id: _newId(), authorId: uid, now: _now());
      await _library.saveUserExercise(exercise);
      _analytics.analytic('CreateExercise_Success');
      emit(
        ExerciseSaveState(status: ExerciseSaveStatus.saved, created: exercise),
      );
    } on Object catch (error) {
      _analytics.severe('CreateExercise_Fail', error);
      emit(const ExerciseSaveState(status: ExerciseSaveStatus.failed));
    }
  }

  /// Back to the review after a failure was shown.
  void failureShown() => emit(const ExerciseSaveState());
}
