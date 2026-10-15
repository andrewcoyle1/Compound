import 'package:flutter_test/flutter_test.dart';
import 'package:health_repository/health_repository.dart';

// HealthKitManagerTests' scope tests: each feature asks only for what it
// uses, as Swift's HealthDataScope does.
void main() {
  group(HealthScope, () {
    test('each scope asks only for what its feature uses', () {
      Map<HealthDataType, HealthDataAccess> ios(HealthScope scope) =>
          scope.permissions(appleHealth: true);
      const rw = HealthDataAccess.READ_WRITE;
      const read = HealthDataAccess.READ;

      expect(ios(HealthScope.workouts), {
        HealthDataType.WORKOUT: rw,
        HealthDataType.ACTIVE_ENERGY_BURNED: rw,
        HealthDataType.HEART_RATE: rw,
      });
      expect(ios(HealthScope.steps), {HealthDataType.STEPS: read});
      expect(ios(HealthScope.bodyMeasurements), {
        HealthDataType.WEIGHT: rw,
        HealthDataType.BODY_FAT_PERCENTAGE: read,
      });
      // Onboarding's "Fill from Apple Health" buttons read one type each
      // and write nothing.
      expect(ios(HealthScope.dateOfBirth), {HealthDataType.BIRTH_DATE: read});
      expect(ios(HealthScope.sex), {HealthDataType.GENDER: read});
      expect(ios(HealthScope.height), {HealthDataType.HEIGHT: read});
      expect(ios(HealthScope.weight), {HealthDataType.WEIGHT: read});
    });

    test('only the nutrition scope reads food, and only energy and macros', () {
      expect(HealthScope.nutrition.permissions(appleHealth: true), {
        HealthDataType.DIETARY_ENERGY_CONSUMED: HealthDataAccess.READ,
        HealthDataType.DIETARY_PROTEIN_CONSUMED: HealthDataAccess.READ,
        HealthDataType.DIETARY_CARBS_CONSUMED: HealthDataAccess.READ,
        HealthDataType.DIETARY_FATS_CONSUMED: HealthDataAccess.READ,
      });
      for (final scope in HealthScope.values) {
        if (scope == HealthScope.nutrition) continue;
        for (final appleHealth in [true, false]) {
          expect(
            scope
                .permissions(appleHealth: appleHealth)
                .keys
                .where(
                  (type) =>
                      type.name.startsWith('DIETARY') ||
                      type == HealthDataType.NUTRITION,
                ),
            isEmpty,
          );
        }
      }
    });

    test(
      'Health Connect: food is one record type; no date of birth or sex',
      () {
        expect(HealthScope.nutrition.permissions(appleHealth: false), {
          HealthDataType.NUTRITION: HealthDataAccess.READ,
        });
        expect(
          HealthScope.dateOfBirth.permissions(appleHealth: false),
          isEmpty,
        );
        expect(HealthScope.sex.permissions(appleHealth: false), isEmpty);
        expect(
          HealthScope.steps.permissions(appleHealth: false),
          HealthScope.steps.permissions(appleHealth: true),
        );
      },
    );

    test('the imports read history', () {
      expect(HealthScope.values.where((scope) => scope.readsHistory), [
        HealthScope.steps,
        HealthScope.bodyMeasurements,
        HealthScope.nutrition,
      ]);
    });
  });
}
