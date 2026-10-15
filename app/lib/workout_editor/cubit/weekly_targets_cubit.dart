import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_session/training_session.dart'
    show newUuid, setTargetsForMicrocycle;

/// A week's override with an id of its own, so its row keeps its identity
/// while its week is stepped.
final class const Variation({
  required final String id,
  required final int fromMicrocycle,
  required final List<SetTarget> setTargets,
}) extends Equatable {
  Variation copyWith({int? fromMicrocycle, List<SetTarget>? setTargets}) =>
      Variation(
        id: id,
        fromMicrocycle: fromMicrocycle ?? this.fromMicrocycle,
        setTargets: setTargets ?? this.setTargets,
      );

  @override
  List<Object> get props => [
    id,
    fromMicrocycle,
    [for (final target in setTargets) target.toFirestore()],
  ];
}

/// The exercise as the targets editor held it, and its variations by week.
final class const WeeklyTargetsState({
  required final WorkoutTemplateExercise exercise,
  required final List<Variation> variations,
}) extends Equatable {
  /// The variations as the exercise stores them.
  List<MicrocycleSetTargets> get overrides => [
    for (final variation in variations)
      MicrocycleSetTargets(
        fromMicrocycle: variation.fromMicrocycle,
        setTargets: variation.setTargets,
      ),
  ];

  /// The week a new variation starts on; null when every week is taken.
  int? get nextWeek => WorkoutEditorRules.nextVariationWeek([
    for (final variation in variations) variation.fromMicrocycle,
  ]);

  /// Whether [variation] can step by [delta]: within 2–52, and never onto
  /// another variation's week.
  bool canStep(Variation variation, int delta) =>
      WorkoutEditorRules.canStepVariation(variation.fromMicrocycle, delta, [
        for (final other in variations)
          if (other.id != variation.id) other.fromMicrocycle,
      ]);

  /// The exercise with [variation]'s targets in place of its base, for the
  /// targets editor to edit as one week.
  WorkoutTemplateExercise exerciseFor(Variation variation) => exercise.copyWith(
    setTargets: variation.setTargets,
    setTargetsByMicrocycle: [],
  );

  @override
  List<Object> get props => [exercise.toFirestore(), variations];
}

/// How a template exercise's targets change from week to week of a
/// mesocycle (Swift `WeeklyTargetsPresenter`): overrides, each taking over
/// from its week until the next, sorted by week. Every change goes back
/// through [_onChange] to the targets editor's working copy.
class WeeklyTargetsCubit extends Cubit<WeeklyTargetsState> {
  new({
    required WorkoutTemplateExercise exercise,
    required this._onChange,
    required this._analytics,
    this._newId = newUuid,
  }) : super(
         WeeklyTargetsState(
           exercise: exercise,
           variations: _sorted([
             for (final override in exercise.setTargetsByMicrocycle)
               Variation(
                 id: _newId(),
                 fromMicrocycle: override.fromMicrocycle,
                 setTargets: override.setTargets,
               ),
           ]),
         ),
       ) {
    _analytics.appear('WeeklyTargetsView');
  }

  final void Function(List<MicrocycleSetTargets>) _onChange;
  final AnalyticsRepository _analytics;
  final String Function() _newId;

  static List<Variation> _sorted(List<Variation> variations) =>
      variations..sort((a, b) => a.fromMicrocycle.compareTo(b.fromMicrocycle));

  void _commit(List<Variation> variations) {
    emit(
      WeeklyTargetsState(
        exercise: state.exercise,
        variations: _sorted([...variations]),
      ),
    );
    _onChange(state.overrides);
  }

  /// Adds a variation from the next free week, starting from the targets of
  /// the week before it as fresh sets, so only what is changed differs.
  void add() {
    final week = state.nextWeek;
    if (week == null) return;
    final seed = setTargetsForMicrocycle(
      state.exercise.copyWith(setTargetsByMicrocycle: state.overrides),
      week - 1,
    );
    _commit([
      ...state.variations,
      Variation(
        id: _newId(),
        fromMicrocycle: week,
        setTargets: [for (final target in seed) target.copyWith(id: _newId())],
      ),
    ]);
    _analytics.analytic('WeeklyTargetsView_AddVariation', {'week': week});
  }

  /// Steps [variation]'s week by [delta], unless it cannot.
  void step(Variation variation, int delta) {
    if (!state.canStep(variation, delta)) return;
    _commit([
      for (final other in state.variations)
        if (other.id == variation.id)
          other.copyWith(fromMicrocycle: other.fromMicrocycle + delta)
        else
          other,
    ]);
  }

  /// Deletes [variation].
  void delete(Variation variation) => _commit([
    for (final other in state.variations)
      if (other.id != variation.id) other,
  ]);

  /// The targets the editor saved for the variation [id].
  void targetsEdited(String id, List<SetTarget> targets) => _commit([
    for (final other in state.variations)
      if (other.id == id) other.copyWith(setTargets: targets) else other,
  ]);
}
