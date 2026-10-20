/// Activities from the athlete's Strava account, at
/// `users/{uid}/strava_activities/{id}` (Swift `StravaImportedActivity`).
/// Only the server writes them (`stravaActivityDoc` in `functions/lib.js`);
/// the apps read them.
///
/// Strava's terms allow showing these to the athlete only: never on a
/// screen anyone else sees.
library;

import 'package:compound_models/src/firestore_values.dart';

/// Field names of a [StravaImportedActivity], exactly as the Swift
/// `CodingKeys` spell them.
abstract final class StravaImportedActivityKeys {
  /// `id`.
  static const id = 'id';

  /// `name`.
  static const name = 'name';

  /// `sport_type`.
  static const sportType = 'sport_type';

  /// `start_date`.
  static const startDate = 'start_date';

  /// `elapsed_time`.
  static const elapsedTime = 'elapsed_time';

  /// `moving_time`.
  static const movingTime = 'moving_time';

  /// `distance`.
  static const distance = 'distance';

  /// `total_elevation_gain`.
  static const totalElevationGain = 'total_elevation_gain';

  /// `average_heartrate`.
  static const averageHeartrate = 'average_heartrate';

  /// Every field, in declaration order.
  static const List<String> all = [
    id,
    name,
    sportType,
    startDate,
    elapsedTime,
    movingTime,
    distance,
    totalElevationGain,
    averageHeartrate,
  ];
}

/// A run, a ride or any other activity copied from Strava (Swift
/// `StravaImportedActivity`). Workouts Compound uploaded are never imported
/// back.
class const StravaImportedActivity({
  /// Strava's activity id, as a string; also the document id.
  required final String id,

  /// Its name on Strava.
  required final String name,

  /// Strava's `sport_type`, such as `Run` or `Ride`.
  required final String sportType,

  /// When it started.
  required final DateTime startDate,

  /// Seconds from start to finish.
  required final int elapsedTime,

  /// Seconds spent moving.
  required final int movingTime,

  /// Metres.
  required final double distance,

  /// Metres climbed.
  final double? totalElevationGain,

  /// Beats per minute, when Strava has a heart rate.
  final double? averageHeartrate,
}) {
  /// Creates a [StravaImportedActivity].
  this;

  /// Decodes strictly, as Swift's synthesized decoder does. The function
  /// writes whole numbers as integers (`0` elevation, a distance of whole
  /// metres), which read as doubles, as Swift widens them.
  factory fromFirestore(Map<String, Object?> data) => StravaImportedActivity(
    id: data[StravaImportedActivityKeys.id]! as String,
    name: data[StravaImportedActivityKeys.name]! as String,
    sportType: data[StravaImportedActivityKeys.sportType]! as String,
    startDate: data[StravaImportedActivityKeys.startDate]! as DateTime,
    elapsedTime: readInt(data[StravaImportedActivityKeys.elapsedTime]),
    movingTime: readInt(data[StravaImportedActivityKeys.movingTime]),
    distance: readDouble(data[StravaImportedActivityKeys.distance]),
    totalElevationGain: readOptionalDouble(
      data[StravaImportedActivityKeys.totalElevationGain],
    ),
    averageHeartrate: readOptionalDouble(
      data[StravaImportedActivityKeys.averageHeartrate],
    ),
  );

  /// The Firestore-shaped map Swift writes: a null field is left out.
  Map<String, Object?> toFirestore() => {
    StravaImportedActivityKeys.id: id,
    StravaImportedActivityKeys.name: name,
    StravaImportedActivityKeys.sportType: sportType,
    StravaImportedActivityKeys.startDate: startDate,
    StravaImportedActivityKeys.elapsedTime: elapsedTime,
    StravaImportedActivityKeys.movingTime: movingTime,
    StravaImportedActivityKeys.distance: distance,
    StravaImportedActivityKeys.totalElevationGain: ?totalElevationGain,
    StravaImportedActivityKeys.averageHeartrate: ?averageHeartrate,
  };

  /// The activity on strava.com (Swift `stravaURL`).
  Uri get stravaUri => Uri.https('www.strava.com', '/activities/$id');
}
