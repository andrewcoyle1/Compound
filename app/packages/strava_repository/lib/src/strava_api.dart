import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:compound_models/compound_models.dart';
import 'package:http/http.dart' as http;
import 'package:strava_repository/src/strava_models.dart';
import 'package:strava_repository/src/strava_strength_file.dart';

/// The form fields sent with the file. [externalId] is what Strava
/// deduplicates on.
class const StravaUpload({
  /// The activity's name.
  required final String name,

  /// Its description, when there is one.
  required final String? description,

  /// `compound-<session id>`.
  required final String externalId,

  /// The strength file.
  required final StravaStrengthFile file,
}) {
  /// Creates a [StravaUpload].
  this;
}

/// The connection and its tokens live on the server, behind the `strava*`
/// callables; the app only ever holds a short-lived access token, which it
/// uses to talk to Strava directly (Swift `StravaService`).
///
/// Every method throws a [StravaException].
abstract interface class StravaApi {
  /// Exchanges an authorization [code], or migrates a [refreshToken] an
  /// older build kept on the device. Exactly one of the two is given.
  Future<StravaConnectResult> connect({
    required String clientId,
    String? code,
    String? refreshToken,
  });

  /// The connected athlete, `null` when this account is not connected.
  Future<StravaAthlete?> connection();

  /// A current access token.
  Future<StravaAccessToken> accessToken();

  /// Revokes Compound at Strava and deletes the connection and the imported
  /// activities on the server.
  Future<void> disconnect();

  /// Starts an upload. A refusal Strava explains, such as a duplicate, comes
  /// back as a status carrying the `error` rather than thrown.
  Future<StravaUploadStatus> upload(StravaUpload upload, String accessToken);

  /// Polls an upload.
  Future<StravaUploadStatus> uploadStatus(int id, String accessToken);

  /// Sends a new name and description to an activity.
  Future<void> updateActivity(
    int id, {
    required String name,
    required String? description,
    required String accessToken,
  });
}

/// The region of the `strava*` callables.
const stravaFunctionsRegion = 'us-central1';

/// Calls the Cloud Function [name] with [data] and returns what it answers,
/// throwing a [FirebaseFunctionsException] when it refuses.
typedef CallFunction = Future<Object?> Function(
  String name,
  Map<String, Object?> data,
);

/// [CallFunction] on Cloud Functions. [functions] must be
/// `FirebaseFunctions.instanceFor(region: stravaFunctionsRegion)` on an app
/// with App Check activated: every callable enforces it.
CallFunction callStravaFunction(FirebaseFunctions functions) =>
    (name, data) async =>
        (await functions.httpsCallable(name).call<Object?>(data)).data;

/// [StravaApi] on the `strava*` callables and Strava's API (Swift
/// `ProductionStravaService`).
class RemoteStravaApi implements StravaApi {
  /// Creates a [RemoteStravaApi]. `boundary` names the multipart boundary,
  /// for tests.
  new({required this._callFunction, required this._client, this._boundary});

  final CallFunction _callFunction;
  final http.Client _client;
  final String Function()? _boundary;

  static final _api = Uri.https('www.strava.com', '/api/v3/');

  @override
  Future<StravaConnectResult> connect({
    required String clientId,
    String? code,
    String? refreshToken,
  }) async => _decode<StravaConnectResult>(
    await _call('stravaConnect', {
      'clientId': clientId,
      'code': ?code,
      'refreshToken': ?refreshToken,
    }),
    StravaConnectResult.fromJson,
  );

  /// `{connected: false}` or `{connected: true, athlete}`.
  @override
  Future<StravaAthlete?> connection() async => _decode<StravaAthlete?>(
    await _call('stravaConnection'),
    (json) => switch (json['athlete']) {
      final Map<Object?, Object?> athlete => StravaAthlete.fromJson(athlete),
      _ => null,
    },
  );

  @override
  Future<StravaAccessToken> accessToken() async => _decode<StravaAccessToken>(
    await _call('stravaAccessToken'),
    StravaAccessToken.fromJson,
  );

  @override
  Future<void> disconnect() => _call('stravaDisconnect');

  /// A `strava*` callable, its refusals read as the app's: permission-denied
  /// is Strava refusing the grant, not-found no connection,
  /// failed-precondition a grant without the upload permission.
  Future<Object?> _call(
    String name, [
    Map<String, Object?> data = const {},
  ]) async {
    try {
      return await _callFunction(name, data);
    } on FirebaseFunctionsException catch (error) {
      throw StravaException(switch (error.code) {
        'permission-denied' => StravaFailure.authorizationRevoked,
        'not-found' => StravaFailure.notConnected,
        'failed-precondition' => StravaFailure.missingUploadPermission,
        _ => StravaFailure.unavailable,
      }, cause: error);
    } on Object catch (error) {
      throw StravaException(StravaFailure.unavailable, cause: error);
    }
  }

  static T _decode<T>(Object? data, T Function(Map<Object?, Object?>) read) {
    try {
      return read(data! as Map<Object?, Object?>);
    } on Object catch (error) {
      throw StravaException(StravaFailure.unavailable, cause: error);
    }
  }

  @override
  Future<StravaUploadStatus> upload(
    StravaUpload upload,
    String accessToken,
  ) async {
    final request = http.Request('POST', _api.resolve('uploads'))
      ..headers['Authorization'] = 'Bearer $accessToken';
    final boundary = _boundary?.call() ?? 'Compound-${newDocumentId()}';
    request
      ..headers['Content-Type'] = 'multipart/form-data; boundary=$boundary'
      ..bodyBytes = multipartBody(upload, boundary);
    final (body, status) = await _send(request);
    // A file Strava refuses outright, a duplicate included, is a 400 whose
    // body is a status.
    if (status >= 200 && status < 300 || status == 400) {
      try {
        return StravaUploadStatus.fromJson(
          jsonDecode(body) as Map<Object?, Object?>,
        );
      } on Object {
        // Not a status: reported by status code below.
      }
    }
    throw StravaException(StravaFailure.uploadFailed, status: status);
  }

  @override
  Future<StravaUploadStatus> uploadStatus(int id, String accessToken) async {
    final request = http.Request('GET', _api.resolve('uploads/$id'))
      ..headers['Authorization'] = 'Bearer $accessToken';
    final (body, status) = await _send(request);
    if (status < 200 || status >= 300) {
      throw StravaException(StravaFailure.uploadFailed, status: status);
    }
    return _decode<StravaUploadStatus>(
      jsonDecode(body),
      StravaUploadStatus.fromJson,
    );
  }

  @override
  Future<void> updateActivity(
    int id, {
    required String name,
    required String? description,
    required String accessToken,
  }) async {
    final request = http.Request('PUT', _api.resolve('activities/$id'))
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..headers['Content-Type'] = 'application/json'
      // An empty description clears it; leaving the key out would keep the
      // old one.
      ..body = jsonEncode({'name': name, 'description': description ?? ''});
    final (_, status) = await _send(request);
    if (status < 200 || status >= 300) {
      throw StravaException(StravaFailure.uploadFailed, status: status);
    }
  }

  /// The body and status, with a 401 (a token Strava no longer accepts) and
  /// a 429 (over Strava's request limit) thrown as such, and a failure to
  /// reach Strava as [StravaFailure.unavailable].
  Future<(String, int)> _send(http.BaseRequest request) async {
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } on Object catch (error) {
      throw StravaException(StravaFailure.unavailable, cause: error);
    }
    if (response.statusCode == 401) {
      throw const StravaException(StravaFailure.authorizationRevoked);
    }
    if (response.statusCode == 429) {
      throw const StravaException(StravaFailure.rateLimited);
    }
    return (response.body, response.statusCode);
  }

  /// The upload as `multipart/form-data`, in Swift's field order: the form
  /// fields, then the file as `workout.json`.
  static List<int> multipartBody(StravaUpload upload, String boundary) {
    final fields = [
      ('data_type', 'json'),
      ('sport_type', 'WeightTraining'),
      ('external_id', upload.externalId),
      ('name', upload.name),
      if (upload.description case final description?)
        ('description', description),
    ];
    final body = StringBuffer();
    for (final (name, value) in fields) {
      body.write(
        '--$boundary\r\nContent-Disposition: form-data; name="$name"'
        '\r\n\r\n$value\r\n',
      );
    }
    body
      ..write(
        '--$boundary\r\nContent-Disposition: form-data; name="file"; '
        'filename="workout.json"\r\nContent-Type: application/json\r\n\r\n',
      )
      ..write(jsonEncode(upload.file.toJson()))
      ..write('\r\n--$boundary--\r\n');
    return utf8.encode(body.toString());
  }
}
