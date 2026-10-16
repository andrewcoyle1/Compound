import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:food_repository/food_repository.dart';

/// The picker's search (Swift `FoodItemSearchPresenter`): Open Food Facts
/// through the `foodSearch` callable, once typing stops. The user's own
/// foods are matched on the device by the view (`libraryMatches`).
class FoodSearchBloc extends Bloc<FoodSearchQueryChanged, FoodSearchState> {
  /// `country` and `language` put the user's own shops and language first
  /// (an Open Food Facts country tag and a two-letter code, from the device
  /// locale). `debounce` is how long typing must stop before the query is
  /// sent.
  new({
    required this._openFoodFacts,
    required this._analyticsRepository,
    this._country,
    this._language,
    this._debounce = const Duration(milliseconds: 700),
  }) : super(const FoodSearchState()) {
    on<FoodSearchQueryChanged>(_onQueryChanged);
  }

  final OpenFoodFacts _openFoodFacts;
  final AnalyticsRepository _analyticsRepository;
  final String? _country;
  final String? _language;
  final Duration _debounce;

  /// Bumped by every query, so a superseded search, which cannot be recalled
  /// once sent, never lands on a newer query's results.
  int _generation = 0;

  Future<void> _onQueryChanged(
    FoodSearchQueryChanged event,
    Emitter<FoodSearchState> emit,
  ) async {
    final generation = ++_generation;
    final query = event.query.trim();
    if (query.isEmpty || !event.searchOnline) {
      emit(FoodSearchState(query: event.query));
      return;
    }
    emit(state.copyWith(query: event.query, status: FoodSearchStatus.idle));
    await Future<void>.delayed(_debounce);
    if (generation != _generation) return;
    emit(state.copyWith(status: FoodSearchStatus.searching));
    try {
      final found = await _openFoodFacts.searchFoods(
        query,
        country: _country,
        language: _language,
      );
      if (generation != _generation) return;
      emit(
        state.copyWith(
          online: event.showBranded
              ? found
              : [
                  for (final food in found)
                    if (food.brandName == null) food,
                ],
          status: FoodSearchStatus.idle,
        ),
      );
    } on Object catch (error) {
      if (generation != _generation) return;
      _analyticsRepository.trackEvent(
        AnalyticsEvent(
          'FoodItemSearchView_SearchError',
          parameters: {'error_description': '$error'},
          type: LogType.severe,
        ),
      );
      emit(state.copyWith(online: const [], status: FoodSearchStatus.failure));
    }
  }
}

/// The search field changed to [query]. [searchOnline] and [showBranded]
/// are the food log settings' Open Food Facts and branded-food switches.
final class const FoodSearchQueryChanged(
  final String query, {
  final bool searchOnline = true,
  final bool showBranded = true,
}) extends Equatable {
  @override
  List<Object?> get props => [query, searchOnline, showBranded];
}

/// Where the online search has got to.
enum FoodSearchStatus {
  /// Waiting for typing to stop, or showing results.
  idle,

  /// A request is out.
  searching,

  /// The request failed; "no results" would claim the food doesn't exist.
  failure,
}

final class const FoodSearchState({
  /// The text in the field.
  final String query = '',

  /// Open Food Facts' results for it.
  final List<FoodModel> online = const [],

  /// Where the search has got to.
  final FoodSearchStatus status = FoodSearchStatus.idle,
}) extends Equatable {
  FoodSearchState copyWith({
    String? query,
    List<FoodModel>? online,
    FoodSearchStatus? status,
  }) => FoodSearchState(
    query: query ?? this.query,
    online: online ?? this.online,
    status: status ?? this.status,
  );

  @override
  List<Object?> get props => [query, online, status];
}
