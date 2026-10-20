import 'package:bloc_test/bloc_test.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/settings/nutrition/bloc/expenditure_estimate_bloc.dart';
import 'package:compound_maths/compound_maths.dart' as maths;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../helpers.dart';

class _MockBodyRepository extends Mock implements BodyRepository;

void main() {
  final now = DateTime(2026, 10, 15, 12);
  late InMemoryCheckInRepository checkIn;

  ExpenditureEstimateBloc build({BodyRepository? body}) =>
      ExpenditureEstimateBloc(
        checkInRepository: checkIn,
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: body ?? InMemoryBodyRepository(),
        userRepository: InMemoryUserRepository(
          users: {uid: const UserModel(userId: uid)},
        ),
        uid: uid,
        now: () => now,
      );

  setUp(() => checkIn = InMemoryCheckInRepository());

  group(ExpenditureEstimateBloc, () {
    test('has no estimate before the settings are read', () {
      expect(build().state.estimate, isNull);
    });

    blocTest<ExpenditureEstimateBloc, ExpenditureEstimateState>(
      'with nothing logged, the estimate is the profile figure',
      build: build,
      act: (bloc) => bloc.add(const ExpenditureEstimateSubscriptionRequested()),
      verify: (bloc) {
        final estimate = bloc.state.estimate!;
        expect(estimate.source, maths.ExpenditureSource.prior);
        expect(estimate.isProvisional, isTrue);
        expect(estimate.day, '2026-10-15');
        expect(bloc.state.user?.userId, uid);
      },
    );

    blocTest<ExpenditureEstimateBloc, ExpenditureEstimateState>(
      'follows the settings: fixed holds the figure',
      setUp: () => checkIn = InMemoryCheckInRepository(
        settings: const [
          NutritionStrategySettings(
            authorId: uid,
            calculationMode: ExpenditureCalculationMode.fixed,
          ),
        ],
      ),
      build: build,
      act: (bloc) => bloc.add(const ExpenditureEstimateSubscriptionRequested()),
      verify: (bloc) =>
          expect(bloc.state.estimate!.source, maths.ExpenditureSource.fixed),
    );

    blocTest<ExpenditureEstimateBloc, ExpenditureEstimateState>(
      'a failing input leaves the estimate standing',
      build: () {
        final body = _MockBodyRepository();
        when(() => body.watchMeasurements(uid))
            .thenAnswer((_) => Stream.error(StateError('offline')));
        when(() => body.watchSteps(uid))
            .thenAnswer((_) => Stream.error(StateError('offline')));
        return build(body: body);
      },
      act: (bloc) => bloc.add(const ExpenditureEstimateSubscriptionRequested()),
      verify: (bloc) {
        expect(bloc.state.estimate, isNotNull);
        expect(bloc.state.measurements, isEmpty);
      },
    );
  });
}
