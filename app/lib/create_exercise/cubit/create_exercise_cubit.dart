import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/create_exercise/logic/exercise_draft.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';

/// The first step's fields: the name, one or two metrics, and optionally
/// the type and laterality.
final class const CreateExerciseState({
  final String name = '',
  final TrackableExerciseMetric? metricA,
  final TrackableExerciseMetric? metricB,
  final ExerciseType? type,
  final Laterality? laterality,
}) extends Equatable {
  bool get _hasName => name.trim().isNotEmpty;

  /// An exercise needs a name and something to log against it.
  bool get canContinue => _hasName && (metricA != null || metricB != null);

  /// Anything typed or picked, which closing would lose.
  bool get hasUnsavedChanges =>
      _hasName ||
      metricA != null ||
      metricB != null ||
      type != null ||
      laterality != null;

  @override
  List<Object?> get props => [name, metricA, metricB, type, laterality];
}

/// The create-exercise flow's first step (Swift `CreateExercisePresenter`):
/// nothing is saved here.
class CreateExerciseCubit extends Cubit<CreateExerciseState> {
  new({required this._analytics}) : super(const CreateExerciseState());

  static const _screen = 'CreateExerciseView';

  final AnalyticsRepository _analytics;

  void appeared() => _analytics.appear(_screen);

  void disappeared() => _analytics.disappear(_screen);

  void nameChanged(String name) => emit(
    CreateExerciseState(
      name: name,
      metricA: state.metricA,
      metricB: state.metricB,
      type: state.type,
      laterality: state.laterality,
    ),
  );

  void metricAChanged(TrackableExerciseMetric? metric) => emit(
    CreateExerciseState(
      name: state.name,
      metricA: metric,
      metricB: state.metricB,
      type: state.type,
      laterality: state.laterality,
    ),
  );

  void metricBChanged(TrackableExerciseMetric? metric) => emit(
    CreateExerciseState(
      name: state.name,
      metricA: state.metricA,
      metricB: metric,
      type: state.type,
      laterality: state.laterality,
    ),
  );

  void typeChanged(ExerciseType? type) => emit(
    CreateExerciseState(
      name: state.name,
      metricA: state.metricA,
      metricB: state.metricB,
      type: type,
      laterality: state.laterality,
    ),
  );

  void lateralityChanged(Laterality? laterality) => emit(
    CreateExerciseState(
      name: state.name,
      metricA: state.metricA,
      metricB: state.metricB,
      type: state.type,
      laterality: laterality,
    ),
  );

  /// The draft the muscle step opens with, the name trimmed; null until
  /// [CreateExerciseState.canContinue]. A second metric chosen alone moves
  /// up to first, here as on screen.
  ExerciseDraft? continued() {
    if (!state.canContinue) return null;
    final promote = state.metricA == null;
    final metricA = state.metricA ?? state.metricB!;
    final metricB = promote ? null : state.metricB;
    emit(
      CreateExerciseState(
        name: state.name,
        metricA: metricA,
        type: state.type,
        laterality: state.laterality,
        metricB: metricB,
      ),
    );
    return ExerciseDraft(
      name: state.name.trim(),
      metricA: metricA,
      metricB: metricB,
      type: state.type,
      laterality: state.laterality,
    );
  }
}
