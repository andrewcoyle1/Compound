import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/create_exercise/logic/exercise_draft.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/training_library/logic/exercise_filters.dart';
import 'package:equatable/equatable.dart';
import 'package:training_session/training_session.dart' show newUuid;

/// The ways of doing the exercise, and whether it is bodyweight work.
final class const ExerciseEquipmentState({
  required final List<VariationDraft> variations,
  final bool isBodyweight = false,
}) extends Equatable {
  /// Bodyweight work needs nothing; anything else needs a variation with
  /// resistance (support alone does not load a lift).
  bool get canContinue =>
      isBodyweight || variations.any((v) => v.resistance.isNotEmpty);

  @override
  List<Object> get props => [variations, isBodyweight];
}

/// The third step (Swift `ExerciseEquipmentPresenter`). There is always at
/// least one variation to fill in.
class ExerciseEquipmentCubit extends Cubit<ExerciseEquipmentState> {
  new({required this._draft, required this._analytics, this._newId = newUuid})
    : super(
        ExerciseEquipmentState(
          variations: _draft.variations.isEmpty
              ? [VariationDraft(id: _newId())]
              : _draft.variations,
          isBodyweight: _draft.isBodyweight,
        ),
      );

  static const _screen = 'ExerciseEquipmentView';

  final ExerciseDraft _draft;
  final AnalyticsRepository _analytics;
  final String Function() _newId;

  void appeared() => _analytics.appear(_screen);

  void disappeared() => _analytics.disappear(_screen);

  void bodyweightChanged({required bool isBodyweight}) => emit(
    ExerciseEquipmentState(
      variations: state.variations,
      isBodyweight: isBodyweight,
    ),
  );

  void variationAdded() =>
      _variations([...state.variations, VariationDraft(id: _newId())]);

  /// Deletes the variation [id], unless it is the last.
  void variationDeleted(String id) {
    if (state.variations.length <= 1) return;
    _variations([
      for (final variation in state.variations)
        if (variation.id != id) variation,
    ]);
  }

  /// The resistance chosen for variation [id]; an unknown id changes
  /// nothing.
  void resistanceChanged(String id, List<EquipmentKey> resistance) =>
      _update(id, (variation) => variation.copyWith(resistance: resistance));

  /// The support chosen for variation [id].
  void supportChanged(String id, List<EquipmentKey> support) =>
      _update(id, (variation) => variation.copyWith(support: support));

  void _update(String id, VariationDraft Function(VariationDraft) change) =>
      _variations([
        for (final variation in state.variations)
          if (variation.id == id) change(variation) else variation,
      ]);

  void _variations(List<VariationDraft> variations) => emit(
    ExerciseEquipmentState(
      variations: variations,
      isBodyweight: state.isBodyweight,
    ),
  );

  /// The draft the final step opens with. A variation with no equipment at
  /// all is dropped: it would count as possible in every gym. Bodyweight
  /// work keeps its equipment (an assisted pull-up's machine). The final
  /// step's fields start again, as Swift's do on each push.
  ExerciseDraft get next => ExerciseDraft(
    name: _draft.name,
    metricA: _draft.metricA,
    metricB: _draft.metricB,
    type: _draft.type,
    laterality: _draft.laterality,
    muscleGroups: _draft.muscleGroups,
    isBodyweight: state.isBodyweight,
    variations: [
      for (final variation in state.variations)
        if (!variation.isEmpty) variation,
    ],
    bodyweightContribution: state.isBodyweight
        ? ExerciseDefinitionRules.bodyweightContributionPreset
        : 0,
  );
}
