// BodyMeasurementKindTests, and the readings cases of
// AnalyticsBodyMetricsPresenterTests and BodyMeasurementDetailPresenterTests.
import 'package:compound/progress/logic/body_metrics.dart';
import 'package:compound_maths/compound_maths.dart' show BodyRatioKind;
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BodyMeasurementEntry entry(
    String id, {
    required int day,
    double? waist,
    double? hip,
    double? neck,
    DateTime? deletedAt,
  }) => BodyMeasurementEntry(
    id: id,
    authorId: 'me',
    waistCircumference: waist,
    hipCircumference: hip,
    neckCircumference: neck,
    date: DateTime(2026, 3, day, 7),
    source: WeightSource.manual,
    dateCreated: DateTime(2026, 3, day, 7),
    deletedAt: deletedAt,
  );

  group(BodyMeasurementKind, () {
    test('every kind has its own field', () {
      final keys = {for (final kind in BodyMeasurementKind.values) kind.key};
      expect(keys, hasLength(18));
      expect(keys, everyElement(isIn(BodyMeasurementEntryKeys.all)));
    });

    test('writing a measurement reads back the same value', () {
      for (final kind in BodyMeasurementKind.values) {
        final updated = kind.update(entry('e', day: 1), 42.5);
        expect(kind.valueOf(updated), 42.5, reason: kind.name);
      }
    });

    test('writing one measurement leaves the others untouched', () {
      final updated = BodyMeasurementKind.waist.update(
        entry('e', day: 1, neck: 38, hip: 99),
        81,
      );
      expect(updated.waistCircumference, 81);
      expect(updated.neckCircumference, 38);
      expect(updated.hipCircumference, 99);
      expect(updated.id, 'e');
    });

    test('each default sits inside its own wheel', () {
      for (final kind in BodyMeasurementKind.values) {
        expect(
          kind.defaultCentimetres,
          inInclusiveRange(kind.centimetres.min, kind.centimetres.max),
          reason: kind.name,
        );
        expect(
          kind.defaultInches,
          inInclusiveRange(kind.inches.min, kind.inches.max),
          reason: kind.name,
        );
      }
    });

    test('the inch wheel agrees with the centimetre wheel', () {
      for (final kind in BodyMeasurementKind.values) {
        expect(
          kind.inches.min,
          closeTo(kind.centimetres.min / centimetresPerInch, 1),
          reason: kind.name,
        );
        expect(
          kind.inches.max,
          closeTo(kind.centimetres.max / centimetresPerInch, 1),
          reason: kind.name,
        );
      }
    });

    test('reads a kind from its raw value', () {
      expect(
        BodyMeasurementKind.tryParse('leftBicep'),
        BodyMeasurementKind.leftBicep,
      );
      expect(BodyMeasurementKind.tryParse('elbow'), isNull);
      expect(BodyMeasurementKind.tryParse(null), isNull);
    });

    test('every circumference is in exactly one group', () {
      final grouped = [
        for (final group in BodyMetricsGroup.values) ...group.kinds,
      ];
      expect(grouped, unorderedEquals(BodyMeasurementKind.values));
      expect(BodyMetricsGroup.weightAndBodyFat.kinds, isEmpty);
    });
  });

  group('readings', () {
    final measurements = [
      entry('b', day: 4, waist: 82),
      entry('a', day: 2, waist: 84),
      entry('neck', day: 3, neck: 38),
      entry('gone', day: 5, waist: 80, deletedAt: DateTime(2026, 3, 6)),
    ];

    test('only entries with this measurement, oldest first', () {
      final waist = entriesOf(measurements, BodyMeasurementKind.waist.valueOf);
      expect([for (final e in waist) e.id], ['a', 'b']);
      expect(
        readingsOf(
          measurements,
          BodyMeasurementKind.waist.valueOf,
        ).map((r) => r.value),
        [84, 82],
      );
    });

    test('a deleted reading is left out', () {
      expect(
        readingsOf(measurements, BodyMeasurementKind.waist.valueOf),
        isNot(
          contains(
            predicate<({DateTime date, double value})>((r) => r.value == 80),
          ),
        ),
      );
    });

    test('lengths convert to inches only for an inches user', () {
      expect(inLength(81.28, LengthUnitPreference.inches), closeTo(32, 1e-9));
      expect(inLength(81.28, LengthUnitPreference.centimeters), 81.28);
      expect(inLength(81.28, null), 81.28);
    });
  });

  group('ratios', () {
    test('waist to height needs a height', () {
      final measurements = [entry('w', day: 4, waist: 80)];
      expect(
        readingsOf(measurements, ratioOf(BodyRatioKind.waistToHeight)),
        isEmpty,
      );
      expect(
        readingsOf(
          measurements,
          ratioOf(BodyRatioKind.waistToHeight, heightCm: 180),
        ).single.value,
        closeTo(0.444, 0.001),
      );
    });

    test('waist to hip needs both on one entry', () {
      final apart = [
        entry('w', day: 4, waist: 80),
        entry('h', day: 6, hip: 100),
      ];
      expect(readingsOf(apart, ratioOf(BodyRatioKind.waistToHip)), isEmpty);
      final together = [entry('both', day: 4, waist: 80, hip: 100)];
      expect(
        readingsOf(together, ratioOf(BodyRatioKind.waistToHip)).single.value,
        0.8,
      );
    });
  });
}
