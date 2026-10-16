import 'dart:math' as math;

import 'package:compound_models/compound_models.dart';

/// Ninety days of [uid]'s body measurements up to [now], for the staging
/// flavor: a weigh-in on most mornings, drifting from about 74 kg down to
/// about 70 kg with day-to-day noise, body fat every week and a few
/// circumferences every fortnight. Most come from Apple Health (with a
/// sample UUID); every third is logged by hand. None is after [now].
List<BodyMeasurementEntry> sampleBodyMeasurements({
  required String uid,
  required DateTime now,
}) => [
  for (var daysAgo = 89; daysAgo >= 0; daysAgo--)
    // A missed weigh-in now and then.
    if (daysAgo % 5 != 3) _entry(uid, now, daysAgo),
]..removeWhere((entry) => entry.date.isAfter(now));

BodyMeasurementEntry _entry(String uid, DateTime now, int daysAgo) {
  final day = DateTime(now.year, now.month, now.day - daysAgo);
  final date = DateTime(day.year, day.month, day.day, 7, 10 + daysAgo % 20);
  final dateKey = _dayKey(day);
  final fromHealth = daysAgo % 3 != 0;
  final weeklyFat = daysAgo % 7 == 0;
  final fortnightlyTape = daysAgo % 14 == 0;
  return BodyMeasurementEntry(
    id: fromHealth ? 'sample-healthkit-$dateKey' : 'sample-weight-$dateKey',
    authorId: uid,
    weightKg: _round(sampleTrendWeightKg(daysAgo) + _noise(daysAgo), 1),
    bodyFatPercentage: weeklyFat ? _round(21.8 + daysAgo * 0.03, 1) : null,
    neckCircumference: fortnightlyTape ? 38.5 : null,
    chestCircumference: fortnightlyTape
        ? _round(100 + daysAgo * 0.01, 1)
        : null,
    waistCircumference: fortnightlyTape ? _round(84 + daysAgo * 0.05, 1) : null,
    hipCircumference: fortnightlyTape ? _round(97 + daysAgo * 0.03, 1) : null,
    leftBicepCircumference: fortnightlyTape ? 34.5 : null,
    rightBicepCircumference: fortnightlyTape ? 35 : null,
    date: date,
    source: fromHealth ? WeightSource.healthkit : WeightSource.manual,
    notes: daysAgo == 27 ? 'Travelling, meals were less consistent.' : null,
    dateCreated: date,
    healthKitUuid: fromHealth
        ? '00000000-0000-4000-8000-${daysAgo.toString().padLeft(12, '0')}'
        : null,
  );
}

/// The weight the samples drift around [daysAgo] days before now: 70.2 kg
/// today, 0.043 kg more for each day back.
double sampleTrendWeightKg(int daysAgo) => 70.2 + daysAgo * 0.043;

/// Deterministic water-and-salt noise of up to about ±0.5 kg.
double _noise(int daysAgo) =>
    0.35 * math.sin(daysAgo * 1.3) + 0.15 * math.sin(daysAgo * 0.45);

/// Thirty days of [uid]'s step counts up to [now], as Apple Health's daily
/// totals: about 9,000 on weekdays and 5,000 at weekends, with a rest day,
/// and today counted only as far as [now].
List<StepsModel> sampleSteps({required String uid, required DateTime now}) => [
  for (var daysAgo = 29; daysAgo >= 0; daysAgo--)
    _steps(uid, now, DateTime(now.year, now.month, now.day - daysAgo), daysAgo),
];

StepsModel _steps(String uid, DateTime now, DateTime day, int daysAgo) {
  final weekend = day.weekday >= DateTime.saturday;
  final wholeDay = daysAgo == 17
      ? 1800
      : (weekend ? 5200 : 9400) + (2400 * math.sin(daysAgo * 1.7)).round();
  final number = daysAgo == 0
      ? wholeDay * (now.hour * 60 + now.minute) ~/ (24 * 60)
      : wholeDay;
  final counted = daysAgo == 0 ? now : day.add(const Duration(hours: 23));
  return StepsModel(
    id: 'sample-steps-${_dayKey(day)}',
    authorId: uid,
    number: number,
    date: day,
    source: StepsSource.healthkit,
    dateCreated: counted,
    dateModified: counted,
  );
}

/// [uid]'s active goal, set at onboarding a month before [now]: lose weight
/// from where the trend stood then down to 68 kg, at 0.3 kg a week. Saved
/// under the user id, as goals from before goal ids are, so it is current
/// for a user with no `currentGoalId`.
WeightGoal sampleWeightGoal({required String uid, required DateTime now}) =>
    WeightGoal(
      goalId: uid,
      userId: uid,
      objective: OverarchingObjective.loseWeight,
      startingWeightKg: _round(sampleTrendWeightKg(30), 1),
      targetWeightKg: 68,
      weeklyChangeKg: 0.3,
      createdAt: now.subtract(const Duration(days: 30)),
      status: GoalStatus.active,
    );

double _round(double value, int places) {
  final scale = math.pow(10, places);
  return (value * scale).round() / scale;
}

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Two of [uid]'s front progress photos a month apart, for the staging
/// flavor, as Swift's `ProgressPhotoModel.mocks`: their images are bundled
/// exercise pictures (`assets/exercises/` in the app), and their weights
/// those of [sampleTrendWeightKg] on the day. Taken at the time of day of
/// [now], so neither is after it.
List<ProgressPhotoModel> sampleProgressPhotos({
  required String uid,
  required DateTime now,
}) => [
  for (final (daysAgo, image) in [
    (30, 'BarbellSquat'),
    (0, 'BarbellBenchPress'),
  ])
    ProgressPhotoModel(
      id: 'sample-progress-photo-$daysAgo',
      authorId: uid,
      date: DateTime(
        now.year,
        now.month,
        now.day - daysAgo,
        now.hour,
        now.minute,
      ),
      pose: ProgressPhotoPose.front,
      storagePath: ProgressPhotoModel.storagePathFor(
        uid,
        'sample-progress-photo-$daysAgo',
      ),
      imageUrl: 'assets/exercises/$image.webp',
      weightKg: _round(sampleTrendWeightKg(daysAgo), 1),
    ),
];
