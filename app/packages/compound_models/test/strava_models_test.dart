import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

void main() {
  group('StravaImportedActivity', () {
    // What stravaActivityDoc in functions/lib.js writes for an activity
    // with whole numbers: the Admin SDK stores them as integers.
    final asWritten = <String, Object?>{
      'id': '42',
      'name': 'Lunch Walk',
      'sport_type': 'Walk',
      'start_date': DateTime.utc(2026, 10, 1, 12),
      'elapsed_time': 1800,
      'moving_time': 1700,
      'distance': 2000,
      'total_elevation_gain': 0,
    };

    test('reads whole numbers written as integers as doubles', () {
      final activity = StravaImportedActivity.fromFirestore(asWritten);

      expect(activity.distance, isA<double>());
      expect(activity.distance, 2000);
      expect(activity.totalElevationGain, 0);
      expect(activity.averageHeartrate, isNull);
    });

    test('requires every field Swift requires', () {
      for (final key in [
        'id',
        'name',
        'sport_type',
        'start_date',
        'elapsed_time',
        'moving_time',
        'distance',
      ]) {
        expect(
          () =>
              StravaImportedActivity.fromFirestore({...asWritten}..remove(key)),
          throwsA(anything),
          reason: key,
        );
      }
    });

    test('links to the activity on strava.com', () {
      expect(
        StravaImportedActivity.fromFirestore(asWritten).stravaUri.toString(),
        'https://www.strava.com/activities/42',
      );
    });
  });
}
