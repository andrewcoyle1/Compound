import 'package:ai_repository/ai_repository.dart';
import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:characters/characters.dart';
import 'package:compound/nutrition/add_meal/cubit/food_photo_scanner_cubit.dart';
import 'package:equatable/equatable.dart';

/// The picker's Describe tab (Swift `MealDescribePresenter`): a meal
/// described in words is sent to `mealDescribe`, and the foods it finds can
/// be added all at once or one at a time through the amount sheet.
class MealDescribeCubit extends Cubit<MealDescribeState> {
  new({required this._ai, required this._analytics})
    : super(const MealDescribeState());

  /// The longest description, in characters as the field counts them.
  static const characterLimit = 500;

  final AiRepository _ai;
  final AnalyticsRepository _analytics;

  /// The field now reads [text], held to [characterLimit].
  void textChanged(String text) {
    final characters = text.characters;
    emit(
      state.copyWith(
        text: characters.length > characterLimit
            ? characters.take(characterLimit).toString()
            : text,
      ),
    );
  }

  /// Analyze: the description goes to the model, forgetting the last
  /// answer. Nothing is sent without a description, or while one is out.
  Future<void> analyse() async {
    if (!state.canAnalyse) return;
    final text = state.text;
    emit(MealDescribeState(text: text, status: EstimateStatus.analysing));
    _track('MealDescribe_Submit', {'text_length': text.characters.length});
    try {
      final items = await _ai.describeMeal(text);
      _track('MealDescribeView_Analyse_Success', {'item_count': items.length});
      if (!isClosed) {
        emit(state.copyWith(status: EstimateStatus.analysed, items: items));
      }
    } on Object catch (error) {
      _track('MealDescribe_Error', {'error': '$error'}, LogType.severe);
      if (!isClosed) emit(state.copyWith(status: EstimateStatus.failed));
    }
  }

  /// Add All: [MealDescribeState.items] go on the plate at their
  /// estimates, once per answer.
  void addAll() {
    if (state.addedAll || state.items.isEmpty) return;
    emit(state.copyWith(addedAll: true));
    _track('MealDescribe_AddAll', {'item_count': state.items.length});
  }

  /// A result's tap, which opens its amount sheet.
  void resultTapped(FoodAnalysisItem item) =>
      _track('MealDescribe_AddItem', {'item_name': item.name});

  void _track(
    String name, [
    Map<String, Object?>? parameters,
    LogType type = LogType.analytic,
  ]) => _analytics.trackEvent(
    AnalyticsEvent(name, parameters: parameters, type: type),
  );
}

final class const MealDescribeState({
  /// The description typed.
  final String text = '',

  /// Where the estimate has got to.
  final EstimateStatus status = EstimateStatus.idle,

  /// The foods found.
  final List<FoodAnalysisItem> items = const [],

  /// Whether Add All has put [items] on the plate.
  final bool addedAll = false,
}) extends Equatable {
  /// Analyze is enabled: there is a description and no answer is awaited.
  bool get canAnalyse =>
      text.trim().isNotEmpty && status != EstimateStatus.analysing;

  MealDescribeState copyWith({
    String? text,
    EstimateStatus? status,
    List<FoodAnalysisItem>? items,
    bool? addedAll,
  }) => MealDescribeState(
    text: text ?? this.text,
    status: status ?? this.status,
    items: items ?? this.items,
    addedAll: addedAll ?? this.addedAll,
  );

  @override
  List<Object?> get props => [text, status, items, addedAll];
}
