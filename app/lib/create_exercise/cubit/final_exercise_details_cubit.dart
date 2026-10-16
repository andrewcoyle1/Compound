import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/create_exercise/logic/exercise_draft.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';

/// The final step's fields, over the draft so far.
final class const FinalExerciseDetailsState({
  required final ExerciseDraft draft,
  final int? contribution,
  final String alternateNames = '',
}) extends Equatable {
  /// The contribution must be a whole percentage; an empty field is not.
  bool get isContributionInRange {
    final contribution = this.contribution;
    return contribution != null &&
        ExerciseDefinitionRules.isValidContribution(contribution);
  }

  /// A bodyweight exercise that also tracks a load.
  bool get hasBodyweightConflict => ExerciseDefinitionRules.bodyweightConflict(
    isBodyweight: draft.isBodyweight,
    metrics: draft.metrics,
  );

  bool get canContinue => isContributionInRange && !hasBodyweightConflict;

  @override
  List<Object?> get props => [draft, contribution, alternateNames];
}

/// The fourth step (Swift `FinalExerciseDetailsPresenter`): range of motion,
/// stability, the body weight contribution, other names and a description.
class FinalExerciseDetailsCubit extends Cubit<FinalExerciseDetailsState> {
  /// The contribution starts at the draft's: 0, or the preset when
  /// Bodyweight Exercise was on.
  new({required ExerciseDraft draft, required this._analytics})
    : super(
        FinalExerciseDetailsState(
          draft: draft,
          contribution: draft.bodyweightContribution,
        ),
      );

  static const _screen = 'FinalExerciseDetailsView';

  final AnalyticsRepository _analytics;

  void appeared() => _analytics.appear(_screen);

  void disappeared() => _analytics.disappear(_screen);

  void rangeOfMotionChanged(int value) =>
      _emit(state.draft.copyWith(rangeOfMotion: value));

  void stabilityChanged(int value) =>
      _emit(state.draft.copyWith(stability: value));

  void descriptionChanged(String value) =>
      _emit(state.draft.copyWith(description: value));

  /// The field as typed; anything but a whole number is out of range.
  void contributionChanged(String text) => emit(
    FinalExerciseDetailsState(
      draft: state.draft,
      contribution: int.tryParse(text.trim()),
      alternateNames: state.alternateNames,
    ),
  );

  /// The names as typed, cut at the limit.
  void alternateNamesChanged(String text) => emit(
    FinalExerciseDetailsState(
      draft: state.draft,
      contribution: state.contribution,
      alternateNames: text.length > ExerciseDefinitionRules.alternateNamesLimit
          ? text.substring(0, ExerciseDefinitionRules.alternateNamesLimit)
          : text,
    ),
  );

  void _emit(ExerciseDraft draft) => emit(
    FinalExerciseDetailsState(
      draft: draft,
      contribution: state.contribution,
      alternateNames: state.alternateNames,
    ),
  );

  /// The draft the review opens with; null until
  /// [FinalExerciseDetailsState.canContinue].
  ExerciseDraft? get next => state.canContinue
      ? state.draft.copyWith(
          bodyweightContribution: state.contribution,
          alternateNames: ExerciseDefinitionRules.splitAlternateNames(
            state.alternateNames,
          ),
        )
      : null;
}
