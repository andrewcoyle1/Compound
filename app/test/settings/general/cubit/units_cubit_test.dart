import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:compound/settings/general/cubit/units_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../recorded_analytics.dart';

class _MockUserRepository extends Mock implements UserRepository;

void main() {
  late UserRepository users;
  late RecordedAnalytics analytics;
  late List<Map<String, Object?>> writes;

  setUp(() {
    users = _MockUserRepository();
    analytics = RecordedAnalytics();
    writes = [];
    when(() => users.updateUserFields(any(), any())).thenAnswer((invocation) {
      final fields = invocation.positionalArguments[1] as List<UserFieldValue>;
      writes.add({for (final field in fields) field.key: field.value});
      return Future.value();
    });
  });

  UnitsCubit build(UnitsState initial) => UnitsCubit(
    users: users,
    analytics: analytics,
    uid: 'uid',
    initial: initial,
  );

  group('usesMetric', () {
    test('follows the region as Swift measurementSystem does', () {
      expect(usesMetric('FR'), isTrue);
      expect(usesMetric('DE'), isTrue);
      expect(usesMetric(null), isTrue);
      expect(usesMetric('US'), isFalse);
      expect(usesMetric('us'), isFalse);
      expect(usesMetric('GB'), isFalse);
      expect(usesMetric('LR'), isFalse);
      expect(usesMetric('MM'), isFalse);
    });
  });

  group('UnitsState.initial', () {
    test('opens on the stored preferences', () {
      final state = UnitsState.initial(
        const UserModel(
          userId: 'uid',
          submittedLengthUnitPreference: LengthUnitPreference.inches,
          submittedWeightUnitPreference: WeightUnitPreference.pounds,
          submittedDistanceUnitPreference: DistanceUnitPreference.miles,
        ),
        isMetric: true,
      );
      expect(
        state,
        const UnitsState(
          weight: WeightUnitPreference.pounds,
          length: LengthUnitPreference.inches,
          distance: DistanceUnitPreference.miles,
        ),
      );
    });

    test('a missing distance preference follows the length one', () {
      expect(
        UnitsState.initial(
          const UserModel(
            userId: 'uid',
            submittedLengthUnitPreference: LengthUnitPreference.inches,
          ),
          isMetric: true,
        ).distance,
        DistanceUnitPreference.miles,
      );
      expect(
        UnitsState.initial(
          const UserModel(
            userId: 'uid',
            submittedLengthUnitPreference: LengthUnitPreference.centimeters,
          ),
          isMetric: false,
        ).distance,
        DistanceUnitPreference.kilometers,
      );
    });

    test('no stored preferences follow the region', () {
      expect(
        UnitsState.initial(null, isMetric: true),
        const UnitsState(
          weight: WeightUnitPreference.kilograms,
          length: LengthUnitPreference.centimeters,
          distance: DistanceUnitPreference.kilometers,
        ),
      );
      expect(
        UnitsState.initial(null, isMetric: false),
        const UnitsState(
          weight: WeightUnitPreference.pounds,
          length: LengthUnitPreference.inches,
          distance: DistanceUnitPreference.miles,
        ),
      );
    });
  });

  group(UnitsCubit, () {
    const metric = UnitsState(
      weight: WeightUnitPreference.kilograms,
      length: LengthUnitPreference.centimeters,
      distance: DistanceUnitPreference.kilometers,
    );

    test(
      'changing one unit writes all three, without resetting the others',
      () async {
        final cubit = build(metric);
        await cubit.lengthChanged(LengthUnitPreference.inches);
        await cubit.weightChanged(WeightUnitPreference.pounds);
        await cubit.distanceChanged(DistanceUnitPreference.miles);

        expect(writes, [
          {
            'submitted_length_unit_preference': 'inches',
            'submitted_weight_unit_preference': 'kilograms',
            'submitted_distance_unit_preference': 'kilometers',
          },
          {
            'submitted_length_unit_preference': 'inches',
            'submitted_weight_unit_preference': 'pounds',
            'submitted_distance_unit_preference': 'kilometers',
          },
          {
            'submitted_length_unit_preference': 'inches',
            'submitted_weight_unit_preference': 'pounds',
            'submitted_distance_unit_preference': 'miles',
          },
        ]);
        verify(() => users.updateUserFields('uid', any())).called(3);
        expect(
          cubit.state,
          const UnitsState(
            weight: WeightUnitPreference.pounds,
            length: LengthUnitPreference.inches,
            distance: DistanceUnitPreference.miles,
          ),
        );
        expect(analytics.names, [
          for (var i = 0; i < 3; i++) ...[
            'UnitsView_Save_Start',
            'UnitsView_Save_Success',
          ],
        ]);
      },
    );

    test('switching a unit and back restores it', () async {
      final cubit = build(metric);
      await cubit.weightChanged(WeightUnitPreference.pounds);
      await cubit.weightChanged(WeightUnitPreference.kilograms);
      expect(cubit.state, metric);
      expect(writes.last, {
        'submitted_length_unit_preference': 'centimeters',
        'submitted_weight_unit_preference': 'kilograms',
        'submitted_distance_unit_preference': 'kilometers',
      });
    });

    test('a failed save says so and is logged as severe', () async {
      when(() => users.updateUserFields(any(), any()))
          .thenThrow(StateError('no'));
      final cubit = build(metric);
      await cubit.weightChanged(WeightUnitPreference.pounds);
      expect(cubit.state.saveFailed, isTrue);
      expect(cubit.state.weight, WeightUnitPreference.pounds);
      expect(analytics.events.last[0], 'UnitsView_Save_Fail');
      expect(analytics.events.last[2], LogType.severe);
    });

    test('a save that fails after closing emits nothing', () async {
      final refusal = Completer<void>();
      when(() => users.updateUserFields(any(), any()))
          .thenAnswer((_) => refusal.future);
      final cubit = build(metric);
      final saving = cubit.weightChanged(WeightUnitPreference.pounds);
      await cubit.close();
      refusal.completeError(StateError('no'));
      await saving;
      expect(cubit.state.saveFailed, isFalse);
    });

    test('appearing and disappearing are tracked', () {
      build(metric)
        ..appeared()
        ..disappeared();
      expect(analytics.screenViews, ['UnitsView_Appear']);
      expect(analytics.names, ['UnitsView_Disappear']);
    });
  });
}
