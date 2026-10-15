import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:compound/nutrition/add_meal/bloc/food_search_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../recording_analytics.dart';

class _MockOpenFoodFacts extends Mock implements OpenFoodFacts;

void main() {
  FoodModel food(String id, {String? brand}) => FoodModel(
    ingredientId: id,
    name: id,
    brandName: brand,
    dateCreated: DateTime.utc(2026),
    dateModified: DateTime.utc(2026),
  );

  final plain = food('apple');
  final branded = food('apple-pie', brand: 'Sample Bakery');

  late OpenFoodFacts openFoodFacts;
  late RecordingAnalytics analytics;

  setUp(() {
    openFoodFacts = _MockOpenFoodFacts();
    analytics = RecordingAnalytics();
    when(
      () => openFoodFacts.searchFoods(
        any(),
        country: any(named: 'country'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) async => [plain, branded]);
  });

  FoodSearchBloc build() => FoodSearchBloc(
    openFoodFacts: openFoodFacts,
    analyticsRepository: analytics,
    country: 'en:ireland',
    language: 'en',
    debounce: Duration.zero,
  );

  group(FoodSearchBloc, () {
    blocTest<FoodSearchBloc, FoodSearchState>(
      "searches once typing stops, in the user's country and language",
      build: build,
      act: (bloc) => bloc.add(const FoodSearchQueryChanged(' apple ')),
      wait: const Duration(milliseconds: 10),
      expect: () => [
        const FoodSearchState(query: ' apple '),
        const FoodSearchState(
          query: ' apple ',
          status: FoodSearchStatus.searching,
        ),
        FoodSearchState(query: ' apple ', online: [plain, branded]),
      ],
      verify: (_) => verify(
        () => openFoodFacts.searchFoods(
          'apple',
          country: 'en:ireland',
          language: 'en',
        ),
      ).called(1),
    );

    blocTest<FoodSearchBloc, FoodSearchState>(
      'leaves out branded foods when the settings say so',
      build: build,
      act: (bloc) =>
          bloc.add(const FoodSearchQueryChanged('apple', showBranded: false)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) => expect(bloc.state.online, [plain]),
    );

    blocTest<FoodSearchBloc, FoodSearchState>(
      'a blank query, or online search turned off, sends nothing',
      build: build,
      act: (bloc) => bloc
        ..add(const FoodSearchQueryChanged('  '))
        ..add(const FoodSearchQueryChanged('apple', searchOnline: false)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.online, isEmpty);
        verifyNever(
          () => openFoodFacts.searchFoods(
            any(),
            country: any(named: 'country'),
            language: any(named: 'language'),
          ),
        );
      },
    );

    blocTest<FoodSearchBloc, FoodSearchState>(
      'a query typed over another sends only the last',
      build: () => FoodSearchBloc(
        openFoodFacts: openFoodFacts,
        analyticsRepository: analytics,
        debounce: const Duration(milliseconds: 20),
      ),
      act: (bloc) => bloc
        ..add(const FoodSearchQueryChanged('app'))
        ..add(const FoodSearchQueryChanged('apple')),
      wait: const Duration(milliseconds: 60),
      verify: (_) {
        verify(() => openFoodFacts.searchFoods('apple')).called(1);
        verifyNever(() => openFoodFacts.searchFoods('app'));
      },
    );

    blocTest<FoodSearchBloc, FoodSearchState>(
      'a superseded answer never lands on the newer query',
      setUp: () {
        final slow = Completer<List<FoodModel>>();
        when(() => openFoodFacts.searchFoods('app'))
            .thenAnswer((_) => slow.future);
        when(() => openFoodFacts.searchFoods('apple')).thenAnswer((_) async {
          slow.complete([branded]);
          return [plain];
        });
      },
      build: () => FoodSearchBloc(
        openFoodFacts: openFoodFacts,
        analyticsRepository: analytics,
        debounce: Duration.zero,
      ),
      act: (bloc) async {
        bloc.add(const FoodSearchQueryChanged('app'));
        await Future<void>.delayed(const Duration(milliseconds: 5));
        bloc.add(const FoodSearchQueryChanged('apple'));
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) => expect(bloc.state.online, [plain]),
    );

    blocTest<FoodSearchBloc, FoodSearchState>(
      'a failed search says so, tracked, rather than "no results"',
      setUp: () => when(
        () => openFoodFacts.searchFoods(
          any(),
          country: any(named: 'country'),
          language: any(named: 'language'),
        ),
      ).thenThrow(const FoodDataException(FoodDataFailure.unavailable)),
      build: build,
      act: (bloc) => bloc.add(const FoodSearchQueryChanged('apple')),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.status, FoodSearchStatus.failure);
        expect(bloc.state.online, isEmpty);
        expect(analytics.names, ['FoodItemSearchView_SearchError']);
      },
    );

    blocTest<FoodSearchBloc, FoodSearchState>(
      'a failure for a superseded query is dropped',
      setUp: () {
        final slow = Completer<List<FoodModel>>();
        when(() => openFoodFacts.searchFoods('app'))
            .thenAnswer((_) => slow.future);
        when(() => openFoodFacts.searchFoods('apple')).thenAnswer((_) async {
          slow.completeError(Exception('late'));
          return [plain];
        });
      },
      build: () => FoodSearchBloc(
        openFoodFacts: openFoodFacts,
        analyticsRepository: analytics,
        debounce: Duration.zero,
      ),
      act: (bloc) async {
        bloc.add(const FoodSearchQueryChanged('app'));
        await Future<void>.delayed(const Duration(milliseconds: 5));
        bloc.add(const FoodSearchQueryChanged('apple'));
      },
      wait: const Duration(milliseconds: 20),
      verify: (bloc) {
        expect(bloc.state.status, FoodSearchStatus.idle);
        expect(analytics.names, isEmpty);
      },
    );
  });
}
