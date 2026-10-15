import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// One set's plan (Swift `SetPlanDetailPresenter`): its kind, and the
/// drops, mini-sets, AMRAP target, partial reps or hold time that kind
/// takes. Every change goes straight back through [_onChange] to the
/// targets editor's working copy, whose own Save and close decide whether
/// it is kept.
class SetPlanDetailCubit extends Cubit<SetTarget> {
  new({
    required SetTarget target,
    required this._onChange,
    required AnalyticsRepository analytics,
  }) : super(target) {
    analytics.appear('SetPlanDetailView');
  }

  final void Function(SetTarget) _onChange;

  void _update(SetTarget target) {
    final planned = WorkoutEditorRules.planned(target);
    emit(planned);
    _onChange(planned);
  }

  /// Makes the set [kind], with a plan to start from. The kind it is
  /// already changes nothing.
  void kindChanged(SetTargetSetType kind) {
    final changed = WorkoutEditorRules.withKind(state, kind);
    if (changed != null) _update(changed);
  }

  /// The drops after the first piece.
  void dropCountChanged(int count) =>
      _update(state.copyWith(dropCount: () => count));

  /// How much lighter each drop is.
  void dropStepPressed(int percent) {
    if (percent == state.dropStep) return;
    _update(state.copyWith(dropStepPercent: () => percent));
  }

  /// The reps on each drop as typed; empty is to failure.
  void dropRepsChanged(double? reps) => _update(
    state.copyWith(dropReps: () => WorkoutEditorRules.plannedReps(reps)),
  );

  /// The mini-sets after the first piece.
  void miniSetCountChanged(int count) =>
      _update(state.copyWith(miniSetCount: () => count));

  /// An AMRAP set's target as typed.
  void amrapTargetChanged(double? reps) => _update(
    state.copyWith(amrapTargetReps: () => WorkoutEditorRules.plannedReps(reps)),
  );

  /// The partial reps after the set; null is to failure.
  void partialRepsChanged(int? reps) =>
      _update(state.copyWith(partialReps: () => reps));

  /// How long the stretch or hold lasts.
  void holdSecondsChanged(int seconds) =>
      _update(state.copyWith(holdSeconds: () => seconds));
}
