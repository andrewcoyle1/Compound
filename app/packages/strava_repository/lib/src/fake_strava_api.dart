import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:strava_repository/src/strava_api.dart';
import 'package:strava_repository/src/strava_models.dart';

/// Two activities in the spirit of Swift's `StravaImportedActivity.mocks`:
/// a run yesterday and a ride three days ago, before [now].
List<StravaImportedActivity> sampleStravaActivities(DateTime now) => [
  StravaImportedActivity(
    id: '1001',
    name: 'Morning Run',
    sportType: 'Run',
    startDate: now.toUtc().subtract(const Duration(days: 1)),
    elapsedTime: 2100,
    movingTime: 1980,
    distance: 6200,
    totalElevationGain: 45,
    averageHeartrate: 151,
  ),
  StravaImportedActivity(
    id: '1002',
    name: 'Evening Ride',
    sportType: 'Ride',
    startDate: now.toUtc().subtract(const Duration(days: 3)),
    elapsedTime: 4000,
    movingTime: 3700,
    distance: 32400,
    totalElevationGain: 310,
  ),
];

/// [StravaApi] for the staging flavor (Swift `MockStravaService`): Strava
/// and the server on the device. Nothing leaves it.
///
/// It behaves as the real pair does where a screen would notice:
/// connecting imports [activities] into [uid]'s `strava_activities` in
/// `firestore`, as the server's import does, and disconnecting deletes
/// them; a second upload of the same workout answers as a duplicate of the
/// first.
class FakeStravaApi implements StravaApi {
  /// Creates a [FakeStravaApi] for [uid], connected as [athlete] when one
  /// is given (and then holding [activities] already).
  new({
    required this._firestore,
    required this.uid,
    StravaAthlete? athlete,
    this.activities = const [],
    DateTime Function()? now,
  }) : _athlete = athlete,
       _now = now ?? DateTime.now {
    if (athlete != null) unawaited(_import());
  }

  final FirebaseFirestore _firestore;
  final DateTime Function() _now;
  StravaAthlete? _athlete;

  /// The signed-in user, whose activities are written.
  final String uid;

  /// What connecting imports.
  final List<StravaImportedActivity> activities;

  /// The athlete every connection is to, as Swift's mock answers.
  static const stagingAthlete = StravaAthlete(
    id: 1,
    firstname: 'Alex',
    lastname: 'Runner',
  );

  /// Every upload received, in order.
  final List<StravaUpload> uploads = [];

  /// Every activity edit received, in order.
  final List<({int id, String name, String? description})> edits = [];

  final _activityIds = <String, int>{};

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(uid).collection('strava_activities');

  StravaAccessToken _token() => StravaAccessToken(
    accessToken: 'staging-access',
    expiresAt: _now().millisecondsSinceEpoch ~/ 1000 + 21600,
  );

  @override
  Future<StravaConnectResult> connect({
    required String clientId,
    String? code,
    String? refreshToken,
  }) async {
    _athlete = stagingAthlete;
    await _import();
    return StravaConnectResult(token: _token(), athlete: stagingAthlete);
  }

  @override
  Future<StravaAthlete?> connection() async => _athlete;

  @override
  Future<StravaAccessToken> accessToken() async => _athlete == null
      ? throw const StravaException(StravaFailure.notConnected)
      : _token();

  @override
  Future<void> disconnect() async {
    _athlete = null;
    for (final document in (await _collection.get()).docs) {
      await document.reference.delete();
    }
  }

  @override
  Future<StravaUploadStatus> upload(
    StravaUpload upload,
    String accessToken,
  ) async {
    uploads.add(upload);
    if (_activityIds[upload.externalId] case final id?) {
      return StravaUploadStatus(
        id: uploads.length,
        error: '${upload.externalId} duplicate of activity $id',
      );
    }
    final id = _activityIds[upload.externalId] = _activityIds.length + 1;
    return StravaUploadStatus(id: uploads.length, activityId: id);
  }

  @override
  Future<StravaUploadStatus> uploadStatus(int id, String accessToken) async =>
      StravaUploadStatus(id: id, activityId: id);

  @override
  Future<void> updateActivity(
    int id, {
    required String name,
    required String? description,
    required String accessToken,
  }) async => edits.add((id: id, name: name, description: description));

  Future<void> _import() async {
    for (final activity in activities) {
      await _collection.doc(activity.id).set({
        ...activity.toFirestore(),
        StravaImportedActivityKeys.startDate: Timestamp.fromDate(
          activity.startDate,
        ),
      });
    }
  }
}
