import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart' show newUuid;

/// What the targets editor offers beside the targets.
sealed class SetTargetScope extends Equatable {
  const new();

  @override
  List<Object> get props => [];
}

/// A template exercise: its targets and its plan (warm-ups, rest, notes,
/// link, substitutions, weekly variation).
final class TemplateScope extends SetTargetScope {
  const new();
}

/// One week's variation of a template exercise: its targets only.
final class const WeekScope(final int week) extends SetTargetScope {
  @override
  List<Object> get props => [week];
}

/// The working copy of one exercise, the link as typed, what the editor
/// offers, and the exercise once saved.
final class const SetTargetState({
  required final WorkoutTemplateExercise exercise,
  required final WorkoutTemplateExercise initial,
  required final String linkText,
  required final SetTargetScope scope,
  required final WorkoutSettings settings,
  final List<ExerciseModel> library = const [],
  final bool showsLinkError = false,
  final WorkoutTemplateExercise? saved,
}) extends Equatable {
  /// Empty, or a web address.
  bool get linkIsValid =>
      linkText.trim().isEmpty ||
      WorkoutEditorRules.validatedLink(linkText) != null;

  /// The plan is offered for a template exercise only.
  bool get showsPlan => scope is TemplateScope;

  /// A week's variation carries targets only.
  bool get showsRestTimers => scope is! WeekScope;

  /// Off, the editor is as it was before the set plan.
  bool get plansSets => settings.setPlanning ?? false;

  /// Closing asks first once anything changed.
  bool get hasUnsavedChanges =>
      !sameDocument(exercise.toFirestore(), initial.toFirestore()) ||
      linkText != (initial.linkUrl ?? '');

  /// The planned alternatives the library knows, in the plan's order.
  List<ExerciseModel> get substitutes => [
    for (final id in exercise.substituteExerciseIds)
      ?library.where((candidate) => candidate.id == id).firstOrNull,
  ];

  SetTargetState copyWith({
    WorkoutTemplateExercise? exercise,
    String? linkText,
    bool? showsLinkError,
    WorkoutTemplateExercise? saved,
  }) => SetTargetState(
    exercise: exercise ?? this.exercise,
    initial: initial,
    linkText: linkText ?? this.linkText,
    scope: scope,
    settings: settings,
    library: library,
    showsLinkError: showsLinkError ?? this.showsLinkError,
    saved: saved ?? this.saved,
  );

  @override
  List<Object?> get props => [
    exercise.toFirestore(),
    linkText,
    scope,
    showsLinkError,
    saved?.toFirestore(),
  ];
}

/// The targets editor (Swift `SetTargetPresenter` and its plan): sets with
/// their reps and RIR, and for a template exercise the warm-ups, rest,
/// notes, link, substitutions and how the targets vary by week. Every edit
/// lands in the working copy; [save] keeps it as [SetTargetState.saved].
class SetTargetCubit extends Cubit<SetTargetState> {
  new({
    required WorkoutTemplateExercise exercise,
    required SetTargetScope scope,
    required WorkoutSettings settings,
    required this._analytics,
    List<ExerciseModel> library = const [],
    this._newId = newUuid,
  }) : super(
         SetTargetState(
           exercise: exercise,
           initial: exercise,
           linkText: exercise.linkUrl ?? '',
           scope: scope,
           settings: settings,
           library: library,
         ),
       ) {
    _analytics.appear(_screen);
  }

  static const _screen = 'SetTargetView';

  final AnalyticsRepository _analytics;
  final String Function() _newId;

  void _edit(WorkoutTemplateExercise exercise) =>
      emit(state.copyWith(exercise: exercise));

  /// Adds a set asking for what the last one did.
  void addSet() => _edit(
    state.exercise.copyWith(
      setTargets: WorkoutEditorRules.addingSet(
        state.exercise.setTargets,
        newId: _newId,
      ),
    ),
  );

  /// Deletes the set [id], numbering the rest again.
  void deleteSet(String id) => _edit(
    state.exercise.copyWith(
      setTargets: WorkoutEditorRules.deletingSet(state.exercise.setTargets, id),
    ),
  );

  /// [target] as edited: its reps, its RIR, or its plan from the detail
  /// sheet.
  void setChanged(SetTarget target) => _edit(
    state.exercise.copyWith(
      setTargets: [
        for (final t in state.exercise.setTargets)
          if (t.id == target.id) target else t,
      ],
    ),
  );

  /// Whether rest timers are set for the exercise.
  void restTimersChanged({required bool on}) =>
      _edit(state.exercise.copyWith(setRestTimers: on));

  /// The warm-up count; null is automatic.
  void warmupsChanged(int? count) =>
      _edit(state.exercise.copyWith(warmupSetCount: () => count));

  /// The rest in seconds; null is automatic.
  void restChanged(int? seconds) =>
      _edit(state.exercise.copyWith(restSeconds: () => seconds));

  /// The notes as typed; trimmed on save.
  void notesChanged(String notes) =>
      _edit(state.exercise.copyWith(notes: () => notes.isEmpty ? null : notes));

  /// The link as typed. It reaches the exercise only once it is a web
  /// address or empty, so a half-typed one is never saved.
  void linkChanged(String text) {
    final next = state.copyWith(linkText: text);
    if (!next.linkIsValid) return emit(next);
    emit(
      next.copyWith(
        exercise: state.exercise.copyWith(
          linkUrl: () => WorkoutEditorRules.validatedLink(text),
        ),
        showsLinkError: false,
      ),
    );
  }

  /// The link was submitted, or its field left: say if it is not an
  /// address.
  void linkSubmitted() =>
      emit(state.copyWith(showsLinkError: !state.linkIsValid));

  /// Adds the ids not already listed, never the exercise itself.
  void substitutionsPicked(List<ExerciseModel> picked) {
    final ids = [...state.exercise.substituteExerciseIds];
    for (final exercise in picked) {
      if (exercise.id == state.exercise.exercise.id) continue;
      if (!ids.contains(exercise.id)) ids.add(exercise.id);
    }
    _edit(state.exercise.copyWith(substituteExerciseIds: ids));
  }

  /// Removes the substitution [id].
  void substitutionRemoved(String id) => _edit(
    state.exercise.copyWith(
      substituteExerciseIds: [
        for (final other in state.exercise.substituteExerciseIds)
          if (other != id) other,
      ],
    ),
  );

  /// The weekly variations as the weekly targets screen left them.
  void variationsChanged(List<MicrocycleSetTargets> overrides) =>
      _edit(state.exercise.copyWith(setTargetsByMicrocycle: overrides));

  /// Keeps the exercise as [SetTargetState.saved]: ranges typed upside down
  /// swapped, notes trimmed. Nothing is kept while the link is not a web
  /// address, which is then shown.
  void save() {
    if (!state.linkIsValid) {
      emit(state.copyWith(showsLinkError: true));
      return;
    }
    final notes = state.exercise.notes?.trim() ?? '';
    emit(
      state.copyWith(
        saved: state.exercise.copyWith(
          setTargets: WorkoutEditorRules.orderedRanges(
            state.exercise.setTargets,
          ),
          notes: () => notes.isEmpty ? null : notes,
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    _analytics.disappear(_screen);
    return super.close();
  }
}
