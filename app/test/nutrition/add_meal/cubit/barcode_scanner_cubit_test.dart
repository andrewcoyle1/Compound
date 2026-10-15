import 'package:bloc_test/bloc_test.dart';
import 'package:compound/nutrition/add_meal/cubit/barcode_scanner_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../recording_analytics.dart';

class _MockOpenFoodFacts extends Mock implements OpenFoodFacts;

class _MockFoodRepository extends Mock implements FoodRepository;

class _FakeFood extends Fake implements FoodModel;

void main() {
  const uid = 'uid';
  const code = '5010029000061';
  final mine = FoodModel(
    ingredientId: 'mine',
    authorId: uid,
    name: 'My Weetabix',
    barcode: code,
    dateCreated: DateTime.utc(2026),
    dateModified: DateTime.utc(2026),
  );
  final product = FoodModel(
    ingredientId: 'off-$code',
    name: 'Weetabix Original',
    barcode: code,
    nutrients: const NutrientMap({NutrientKey.calories: 362}),
    dateCreated: DateTime.utc(2026),
    dateModified: DateTime.utc(2026),
  );

  late OpenFoodFacts openFoodFacts;
  late FoodRepository foods;
  late RecordingAnalytics analytics;

  setUpAll(() => registerFallbackValue(_FakeFood()));

  setUp(() {
    openFoodFacts = _MockOpenFoodFacts();
    foods = _MockFoodRepository();
    analytics = RecordingAnalytics();
    when(() => openFoodFacts.lookupBarcode(code))
        .thenAnswer((_) async => product);
    when(() => foods.saveFood(any())).thenAnswer((_) async {});
  });

  BarcodeScannerCubit build() => BarcodeScannerCubit(
    uid: uid,
    openFoodFacts: openFoodFacts,
    foodRepository: foods,
    analyticsRepository: analytics,
  );

  group(BarcodeScannerCubit, () {
    blocTest<BarcodeScannerCubit, BarcodeScannerState>(
      "finds the user's own food first, without a lookup",
      build: build,
      act: (cubit) => cubit.detected(' $code ', library: [mine]),
      expect: () => [
        const BarcodeScannerState(code: code, status: BarcodeStatus.lookingUp),
        BarcodeScannerState(
          code: code,
          status: BarcodeStatus.found,
          food: mine,
        ),
      ],
      verify: (_) {
        verifyNever(() => openFoodFacts.lookupBarcode(any()));
        expect(
          analytics.names.last,
          'BarcodeScannerView_LookupBarcode_Success',
        );
        expect(analytics.events.last.$2, {'source': 'library'});
      },
    );

    blocTest<BarcodeScannerCubit, BarcodeScannerState>(
      'otherwise looks it up and saves it to the library as the user',
      build: build,
      act: (cubit) => cubit.detected(code, library: const []),
      verify: (cubit) {
        final saved =
            verify(() => foods.saveFood(captureAny())).captured.single
                as FoodModel;
        expect(saved.toFirestore(), {
          ...product.toFirestore(),
          FoodModelKeys.authorId: uid,
        });
        expect(cubit.state.food?.authorId, uid);
        expect(analytics.names, [
          'BarcodeScanner_BarcodeDetected',
          'BarcodeScannerView_LookupBarcode_Success',
        ]);
      },
    );

    blocTest<BarcodeScannerCubit, BarcodeScannerState>(
      'a failed library save still finds the food, and is tracked',
      setUp: () =>
          when(() => foods.saveFood(any()))
              .thenAnswer((_) async => throw Exception('refused')),
      build: build,
      act: (cubit) => cubit.detected(code, library: const []),
      verify: (cubit) {
        expect(cubit.state.status, BarcodeStatus.found);
        expect(analytics.names, contains('BarcodeScannerView_CacheFood_Fail'));
      },
    );

    blocTest<BarcodeScannerCubit, BarcodeScannerState>(
      'the same code again is looked up once, until a rescan',
      build: build,
      act: (cubit) async {
        await cubit.detected(code, library: const []);
        await cubit.detected(code, library: const []);
        cubit.rescan();
        await cubit.detected(code, library: const []);
      },
      verify: (_) => verify(() => openFoodFacts.lookupBarcode(code)).called(2),
    );

    blocTest<BarcodeScannerCubit, BarcodeScannerState>(
      'a blank code does nothing',
      build: build,
      act: (cubit) => cubit.detected('  ', library: const []),
      expect: () => const <BarcodeScannerState>[],
    );

    blocTest<BarcodeScannerCubit, BarcodeScannerState>(
      'a product Open Food Facts does not have is "not found"',
      setUp: () =>
          when(() => openFoodFacts.lookupBarcode(code))
              .thenThrow(const FoodDataException(FoodDataFailure.notFound)),
      build: build,
      act: (cubit) => cubit.detected(code, library: const []),
      verify: (cubit) {
        expect(cubit.state.status, BarcodeStatus.notFound);
        expect(analytics.names.last, 'BarcodeScanner_BarcodeError');
      },
    );

    blocTest<BarcodeScannerCubit, BarcodeScannerState>(
      'a rate limit or network failure is "unavailable", not "not found"',
      setUp: () =>
          when(() => openFoodFacts.lookupBarcode(code))
              .thenThrow(const FoodDataException(FoodDataFailure.rateLimited)),
      build: build,
      act: (cubit) => cubit.detected(code, library: const []),
      verify: (cubit) => expect(cubit.state.status, BarcodeStatus.unavailable),
    );
  });
}
