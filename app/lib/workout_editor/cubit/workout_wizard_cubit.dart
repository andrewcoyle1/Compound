import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart' show newUuid;

/// Where the wizard's save is.
enum WorkoutWizardStatus { editing, saving, saved, failed }

/// The workout being made or edited: its name, the gym, and the exercises
/// chosen, which outlive backing out to the name or gym.
final class const WorkoutWizardState({
  required final String name,
  required final List<WorkoutTemplateExercise> exercises,
  final WorkoutTemplateModel? template,
  final GymProfileModel? gym,
  final WorkoutWizardStatus status = WorkoutWizardStatus.editing,
}) extends Equatable {
  /// Whether this edits a saved workout rather than making one.
  bool get isEditing => template != null;

  /// A workout cannot be named nothing.
  bool get canContinue => name.trim().isNotEmpty;

  /// An empty workout starts with nothing to do, and a second tap mid-save
  /// would write it twice.
  bool get canSave =>
      exercises.isNotEmpty && status != WorkoutWizardStatus.saving;

  WorkoutWizardState copyWith({
    String? name,
    List<WorkoutTemplateExercise>? exercises,
    GymProfileModel? Function()? gym,
    WorkoutWizardStatus? status,
  }) => WorkoutWizardState(
    name: name ?? this.name,
    exercises: exercises ?? this.exercises,
    template: template,
    gym: gym == null ? this.gym : gym(),
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [
    name,
    [for (final exercise in exercises) exercise.toFirestore()],
    template?.workoutId,
    gym?.id,
    status,
  ];
}

/// The workout wizard (Swift `NameWorkoutPresenter`,
/// `ChooseGymProfilePresenter` and `DefineWorkoutWrapperPresenter`): name,
/// then gym when there is one to choose, then the exercises, then Save. A
/// saved workout opens with its name and exercises, and saves in place.
class WorkoutWizardCubit extends Cubit<WorkoutWizardState> {
  /// Opens on `template` when editing it. `uid` is the signed-in user, who
  /// authors a new workout; without one nothing is saved.
  new({
    required this._uid,
    required this._library,
    required this._analytics,
    WorkoutTemplateModel? template,
    this._now = DateTime.now,
    this._newId = newUuid,
  }) : super(
         WorkoutWizardState(
           name: template?.name ?? '',
           exercises: template?.exercises ?? const [],
           template: template,
         ),
       );

  final String? _uid;
  final TrainingLibraryRepository _library;
  final AnalyticsRepository _analytics;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Records one of the wizard's screens appearing: `NameWorkoutView`,
  /// `ChooseGymProfileView` or `DefineWorkoutWrapperView`.
  void appeared(String screen) => _analytics.appear(screen);

  /// Records one of the wizard's screens going.
  void disappeared(String screen) => _analytics.disappear(screen);

  /// The name as typed.
  void nameChanged(String name) => emit(state.copyWith(name: name));

  /// Continues from the name, trimmed, with the gym to build for when there
  /// is nothing to choose (the edited workout's, while it still exists, or
  /// the only one); with none, the chooser is shown.
  void continued(List<GymProfileModel> gyms) => emit(
    state.copyWith(
      name: state.name.trim(),
      gym: () => WorkoutEditorRules.gymWithoutAsking(state.template, gyms),
    ),
  );

  /// The gym chosen in the chooser.
  void gymChosen(GymProfileModel gym) => emit(state.copyWith(gym: () => gym));

  /// The exercises as the editor left them.
  void exercisesChanged(List<WorkoutTemplateExercise> exercises) =>
      emit(state.copyWith(exercises: exercises));

  /// Saves the workout, new or in place, between
  /// `DefineWorkoutWrapperView_SaveWorkout_Start` and `_Success` or a severe
  /// `_Fail`. Without a user it fails without writing.
  Future<void> save() async {
    final gym = state.gym;
    if (!state.canSave || gym == null) return;
    final uid = _uid;
    if (uid == null) {
      emit(state.copyWith(status: WorkoutWizardStatus.failed));
      return;
    }
    final parameters = {'is_new': !state.isEditing};
    emit(state.copyWith(status: WorkoutWizardStatus.saving));
    _analytics.analytic(
      'DefineWorkoutWrapperView_SaveWorkout_Start',
      parameters,
    );
    try {
      await _library.saveWorkoutTemplate(
        WorkoutEditorRules.savedTemplate(
          existing: state.template,
          uid: uid,
          name: state.name.trim(),
          gymProfileId: gym.id,
          exercises: state.exercises,
          now: _now(),
          newId: _newId,
        ),
      );
      _analytics.analytic(
        'DefineWorkoutWrapperView_SaveWorkout_Success',
        parameters,
      );
      emit(state.copyWith(status: WorkoutWizardStatus.saved));
    } on Object catch (error) {
      _analytics.severe('DefineWorkoutWrapperView_SaveWorkout_Fail', error);
      emit(state.copyWith(status: WorkoutWizardStatus.failed));
    }
  }

  /// Back to editing after a failure was shown.
  void failureShown() =>
      emit(state.copyWith(status: WorkoutWizardStatus.editing));
}
