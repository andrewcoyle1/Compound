import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// Where a Save as Template stands.
enum SaveSessionTemplateStatus { idle, saving, saved, unresolved, failed }

final class const SaveSessionTemplateState({
  final SaveSessionTemplateStatus status = SaveSessionTemplateStatus.idle,

  /// What the saved template is called.
  final String? savedName,
}) extends Equatable {
  @override
  List<Object?> get props => [status, savedName];
}

/// A feed card's Save as Template (`WorkoutSessionRowPresenter
/// .onSaveAsTemplatePressed`): the card's workout copied into the reader's
/// library, on every card, the reader's own included.
class SaveSessionTemplateCubit extends Cubit<SaveSessionTemplateState> {
  new({
    required this._library,
    required this._analytics,
    required this._session,
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : super(const SaveSessionTemplateState());

  final TrainingLibraryRepository _library;
  final AnalyticsRepository _analytics;
  final WorkoutSessionModel _session;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Saves the workout as [viewerId]'s template, named [copyName] of it
  /// when they already have one of its name.
  Future<void> savePressed({
    required String? viewerId,
    required String Function(String name) copyName,
  }) async {
    emit(const SaveSessionTemplateState(status: .saving));
    if (viewerId == null) {
      emit(const SaveSessionTemplateState(status: .failed));
      return;
    }
    try {
      final catalogue = PrebuiltCatalogue.instance;
      final template = workoutTemplateFromSession(
        _session,
        library: [
          ...await _library.watchUserExercises(viewerId).first,
          ...catalogue.exercises,
        ],
        existing: [
          ...await _library.watchUserWorkoutTemplates(viewerId).first,
          ...catalogue.workoutTemplates,
        ],
        authorId: viewerId,
        copyName: copyName,
        now: _now(),
        newId: _newId,
      );
      if (template == null) {
        _track('Unresolved', {'session_id': _session.id});
        emit(const SaveSessionTemplateState(status: .unresolved));
        return;
      }
      _track('Start');
      await _library.saveWorkoutTemplate(template);
      _track('Success', {
        'session_id': _session.id,
        'exercise_count': template.exercises.length,
      });
      emit(SaveSessionTemplateState(status: .saved, savedName: template.name));
    } on Object catch (error) {
      _track('Fail', {'error_description': '$error'}, LogType.severe);
      emit(const SaveSessionTemplateState(status: .failed));
    }
  }

  void _track(
    String name, [
    Map<String, Object?>? parameters,
    LogType type = LogType.analytic,
  ]) => _analytics.trackEvent(
    AnalyticsEvent(
      'WorkoutSessionRow_SaveAsTemplate_$name',
      parameters: parameters,
      type: type,
    ),
  );
}
