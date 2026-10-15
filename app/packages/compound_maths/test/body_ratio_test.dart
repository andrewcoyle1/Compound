// The ratio cases of AnalyticsBodyMetricsPresenterTests, and the NICE and
// WHO bands of BodyRatioBand.
import 'package:compound_maths/compound_maths.dart';
import 'package:test/test.dart';

void main() {
  group('body ratio', () {
    test('waist to height needs a height', () {
      expect(bodyRatio(BodyRatioKind.waistToHeight, waistCm: 80), isNull);
      expect(
        bodyRatio(BodyRatioKind.waistToHeight, waistCm: 80, heightCm: 0),
        isNull,
      );
    });

    test('waist to height divides centimetres by centimetres', () {
      expect(
        bodyRatio(BodyRatioKind.waistToHeight, waistCm: 80, heightCm: 180),
        closeTo(0.444, 0.001),
      );
    });

    test('waist to hip needs both on one entry', () {
      expect(bodyRatio(BodyRatioKind.waistToHip, waistCm: 80), isNull);
      expect(bodyRatio(BodyRatioKind.waistToHip, waistCm: null), isNull);
      expect(
        bodyRatio(BodyRatioKind.waistToHip, waistCm: 0, hipCm: 100),
        isNull,
      );
    });

    test('waist to hip uses one day’s pair', () {
      expect(bodyRatio(BodyRatioKind.waistToHip, waistCm: 80, hipCm: 100), 0.8);
    });
  });

  group('screening band', () {
    test('waist to height follows NICE', () {
      BodyRatioBand? band(double r) =>
          bodyRatioBand(BodyRatioKind.waistToHeight, r, null);
      expect(band(0.45), BodyRatioBand.underHalfHeight);
      expect(band(0.5), BodyRatioBand.increasedRisk);
      expect(band(0.6), BodyRatioBand.highRisk);
    });

    test('waist to hip uses the cut-off for the sex', () {
      expect(
        bodyRatioBand(BodyRatioKind.waistToHip, 0.88, Gender.male),
        BodyRatioBand.belowCutOff,
      );
      expect(
        bodyRatioBand(BodyRatioKind.waistToHip, 0.88, Gender.female),
        BodyRatioBand.substantiallyIncreasedRisk,
      );
      expect(
        bodyRatioBand(BodyRatioKind.waistToHip, 0.95, Gender.preferNotToSay),
        isNull,
      );
      expect(waistToHipCutOff(null), isNull);
    });

    test('only the risk bands are a concern', () {
      expect(
        [for (final b in BodyRatioBand.values) b.isConcern],
        [false, true, true, false, true],
      );
    });
  });
}
