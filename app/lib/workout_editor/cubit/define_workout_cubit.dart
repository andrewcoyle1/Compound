import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart' show newUuid;

/// The list's modes: reordering and deleting, and choosing a superset; and
/// whether the picker has opened on its own.
final class const DefineWorkoutState({
  final bool isEditing = false,
  final bool isSelectingSuperset = false,
  final Set<String> supersetSelection = const {},
  final bool autoOpenedPicker = false,
}) extends Equatable {
  /// Two or more chosen can become a superset.
  bool get canConfirmSuperset => supersetSelection.length >= 2;

  /// The list's modes changed, the picker's opening kept.
  DefineWorkoutState mode({
    bool isEditing = false,
    bool isSelectingSuperset = false,
    Set<String> supersetSelection = const {},
  }) => DefineWorkoutState(
    isEditing: isEditing,
    isSelectingSuperset: isSelectingSuperset,
    supersetSelection: supersetSelection,
    autoOpenedPicker: autoOpenedPicker,
  );

  @override
  List<Object> get props => [
    isEditing,
    isSelectingSuperset,
    supersetSelection,
    autoOpenedPicker,
  ];
}

/// The workout editor's list (Swift `DefineWorkoutPresenter`), hosted by
/// the workout wizard and by a mesocycle's day. The exercises belong to the
/// host: [_read] gives them as they stand and [_write] hands back each
/// change, as Swift's `Binding` does. Logs no screen of its own; its hosts
/// do.
class DefineWorkoutCubit extends Cubit<DefineWorkoutState> {
  new({
    required this._read,
    required this._write,
    required this._analytics,
    this._newId = newUuid,
  }) : super(const DefineWorkoutState());

  final List<WorkoutTemplateExercise> Function() _read;
  final void Function(List<WorkoutTemplateExercise>) _write;
  final AnalyticsRepository _analytics;
  final String Function() _newId;

  /// The editor appeared. With [autoOpens], an empty workout opens the
  /// picker on its own, once, as adding exercises is the only thing to do
  /// ([DefineWorkoutState.autoOpenedPicker]). A mesocycle day passes false,
  /// as empty is a rest day.
  void appeared({required bool autoOpens}) {
    if (!autoOpens || state.autoOpenedPicker || _read().isNotEmpty) return;
    emit(
      DefineWorkoutState(
        isEditing: state.isEditing,
        isSelectingSuperset: state.isSelectingSuperset,
        supersetSelection: state.supersetSelection,
        autoOpenedPicker: true,
      ),
    );
  }

  /// The exercises picked, after those there; one already there is not
  /// added again.
  void picked(List<ExerciseModel> picked) =>
      _write(WorkoutEditorRules.addingPicked(_read(), picked, newId: _newId));

  /// [exercise] as the targets editor saved it.
  void exerciseEdited(WorkoutTemplateExercise exercise) => _write([
    for (final e in _read())
      if (e.id == exercise.id) exercise else e,
  ]);

  /// Removes [id]; a superset left with one member is dissolved.
  void removeExercise(String id) {
    final exercises = _read();
    if (!exercises.any((e) => e.id == id)) return;
    _write(
      WorkoutEditorRules.dissolvingLoneGroups([
        for (final e in exercises)
          if (e.id != id) e,
      ]),
    );
  }

  /// Moves the row at [from] to [to] (counted before the move); a superset
  /// moves as one.
  void moveExercise(int from, int to) =>
      _write(WorkoutEditorRules.moving(_read(), {from}, to));

  /// Turns reordering and deleting on or off.
  void editingChanged({required bool isEditing}) =>
      emit(state.mode(isEditing: isEditing));

  /// Starts choosing exercises to run as one superset: two at least.
  void supersetPressed() {
    if (_read().length < 2) return;
    emit(state.mode(isSelectingSuperset: true));
  }

  /// Ticks or unticks [id] for the superset.
  void supersetRowPressed(String id) {
    if (!state.isSelectingSuperset) return;
    final selection = {...state.supersetSelection};
    if (!selection.remove(id)) selection.add(id);
    emit(state.mode(isSelectingSuperset: true, supersetSelection: selection));
  }

  /// Stops choosing, changing nothing.
  void supersetCancelled() => emit(state.mode());

  /// The chosen two or more become one superset where the first of them
  /// is.
  void supersetConfirmed() {
    if (!state.canConfirmSuperset) return;
    final count = state.supersetSelection.length;
    _write(
      WorkoutEditorRules.grouping(
        state.supersetSelection,
        _read(),
        groupId: _newId(),
      ),
    );
    emit(state.mode());
    _analytics.analytic('DefineWorkoutView_Superset_Created', {
      'exercise_count': count,
    });
  }

  /// Takes [id] out of its superset.
  void removedFromSuperset(String id) {
    _write(WorkoutEditorRules.removingFromSuperset(id, _read()));
    _analytics.analytic('DefineWorkoutView_Superset_Removed');
  }
}
