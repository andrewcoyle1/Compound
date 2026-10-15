// RemoteStravaApi: the callables' payloads and refusals (Swift
// ProductionStravaService.call, and the shapes functions/index.js answers),
// and Strava's upload API over HTTP.
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:strava_repository/strava_repository.dart';

import '../helpers/fixtures.dart';

void main() {
  late List<(String, Map<String, Object?>)> calls;
  late Object? Function(String name) answer;
  late List<http.Request> requests;
  late http.Response Function(http.Request request) respond;
  late RemoteStravaApi subject;

  setUp(() {
    calls = [];
    answer = (_) => const <String, Object?>{};
    requests = [];
    respond = (_) => http.Response('{}', 200);
    subject = RemoteStravaApi(
      callFunction: (name, data) async {
        calls.add((name, data));
        return answer(name);
      },
      client: MockClient((request) async {
        requests.add(request);
        return respond(request);
      }),
      boundary: () => 'B',
    );
  });

  final upload = StravaUpload(
    name: 'Leg Day',
    description: null,
    externalId: 'compound-1',
    file: StravaStrengthFile.from(session(), const [])!,
  );

  group('callables', () {
    test('connect sends the client id and the code', () async {
      answer = (_) => {
        'access_token': 'a',
        'expires_at': 100,
        'athlete': {
          'id': 7,
          'firstname': 'Ann',
          'lastname': '',
          'profile': 'https://a/p.jpg',
        },
      };

      final result = await subject.connect(clientId: '42', code: 'c');

      expect(calls.single.$1, 'stravaConnect');
      expect(calls.single.$2, {'clientId': '42', 'code': 'c'});
      expect(result.token.accessToken, 'a');
      expect(result.token.expiresAt, 100);
      expect(result.athlete.name, 'Ann');
      expect(result.athlete.profile, 'https://a/p.jpg');
    });

    test('connect can migrate a refresh token instead', () async {
      answer = (_) => {
        'access_token': 'a',
        'expires_at': 100,
        'athlete': {'id': 7},
      };

      await subject.connect(clientId: '42', refreshToken: 'r');

      expect(calls.single.$2, {'clientId': '42', 'refreshToken': 'r'});
    });

    test('connection reads the athlete, or none', () async {
      answer = (_) => {
        'connected': true,
        'athlete': {'id': 7, 'firstname': 'Ann'},
      };
      expect(
        await subject.connection(),
        const StravaAthlete(id: 7, firstname: 'Ann'),
      );

      answer = (_) => {'connected': false};
      expect(await subject.connection(), isNull);
      expect(calls.map((call) => call.$1), [
        'stravaConnection',
        'stravaConnection',
      ]);
    });

    test('accessToken reads the token', () async {
      answer = (_) => {'access_token': 't', 'expires_at': 5};

      final token = await subject.accessToken();

      expect(token.accessToken, 't');
      expect(token.expiresAt, 5);
      expect(calls.single, ('stravaAccessToken', const <String, Object?>{}));
    });

    test('disconnect calls stravaDisconnect', () async {
      await subject.disconnect();
      expect(calls.single.$1, 'stravaDisconnect');
    });

    for (final (code, failure) in [
      ('permission-denied', StravaFailure.authorizationRevoked),
      ('not-found', StravaFailure.notConnected),
      ('failed-precondition', StravaFailure.missingUploadPermission),
      ('unavailable', StravaFailure.unavailable),
      ('invalid-argument', StravaFailure.unavailable),
    ]) {
      test('reads $code as ${failure.name}', () async {
        answer = (_) =>
            throw FirebaseFunctionsException(message: code, code: code);

        await expectLater(
          subject.accessToken(),
          throwsA(
            isA<StravaException>().having((e) => e.failure, 'failure', failure),
          ),
        );
      });
    }

    test('reads any other failure as unavailable', () async {
      answer = (_) => throw StateError('offline');

      await expectLater(
        subject.disconnect(),
        throwsA(
          isA<StravaException>().having(
            (e) => e.failure,
            'failure',
            StravaFailure.unavailable,
          ),
        ),
      );
    });

    test('reads an answer of the wrong shape as unavailable', () async {
      answer = (_) => 'nonsense';

      await expectLater(
        subject.accessToken(),
        throwsA(
          isA<StravaException>().having(
            (e) => e.failure,
            'failure',
            StravaFailure.unavailable,
          ),
        ),
      );
    });
  });

  group('upload', () {
    test('posts the form and the file with the bearer token', () async {
      respond = (_) => http.Response(
        '{"id": 123456, "id_str": "123456", "external_id": "compound-1", '
        '"error": null, "status": "Your activity is ready.", '
        '"activity_id": 153243126}',
        201,
      );

      final status = await subject.upload(upload, 'tok');

      expect(
        status,
        const StravaUploadStatus(id: 123456, activityId: 153243126),
      );
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://www.strava.com/api/v3/uploads');
      expect(request.headers['Authorization'], 'Bearer tok');
      expect(
        request.headers['Content-Type'],
        'multipart/form-data; boundary=B',
      );
      final body = request.body;
      expect(body, contains('name="data_type"\r\n\r\njson\r\n'));
      expect(body, contains('name="sport_type"\r\n\r\nWeightTraining\r\n'));
      expect(body, contains('name="external_id"\r\n\r\ncompound-1\r\n'));
      expect(body, contains('name="name"\r\n\r\nLeg Day\r\n'));
      expect(body, isNot(contains('name="description"')));
      expect(
        body,
        contains(
          'name="file"; filename="workout.json"\r\n'
          'Content-Type: application/json\r\n\r\n',
        ),
      );
      expect(body, contains('"exercise_type":"BARBELL_BENCH_PRESS"'));
      expect(body, endsWith('--B--\r\n'));
    });

    test('sends a description when there is one', () {
      final body = utf8.decode(
        RemoteStravaApi.multipartBody(
          StravaUpload(
            name: 'n',
            description: 'Felt strong',
            externalId: 'e',
            file: upload.file,
          ),
          'B',
        ),
      );
      expect(body, contains('name="description"\r\n\r\nFelt strong\r\n'));
    });

    test('picks a fresh boundary by default', () async {
      final api = RemoteStravaApi(
        callFunction: (_, _) async => null,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"id": 1}', 201);
        }),
      );

      await api.upload(upload, 'tok');

      expect(
        requests.single.headers['Content-Type'],
        matches(RegExp(r'boundary=Compound-[0-9A-F-]{36}$')),
      );
    });

    // A file Strava refuses outright, a duplicate included, is a 400 whose
    // body is a status.
    test('answers a 400 status rather than throwing', () async {
      respond = (_) => http.Response(
        '{"id": 9, "error": "compound-1 duplicate of activity 21234316"}',
        400,
      );

      final status = await subject.upload(upload, 'tok');

      expect(status.duplicateActivityId, 21234316);
      expect(status.activityId, isNull);
    });

    for (final (code, body) in [
      (400, 'not json'),
      (500, '{"id": 1}'),
      (200, '[]'),
    ]) {
      test('throws uploadFailed for a $code it cannot read', () async {
        respond = (_) => http.Response(body, code);

        await expectLater(
          subject.upload(upload, 'tok'),
          throwsA(
            isA<StravaException>()
                .having((e) => e.failure, 'failure', StravaFailure.uploadFailed)
                .having((e) => e.status, 'status', code),
          ),
        );
      });
    }

    test(
      'throws a 401 as authorizationRevoked and a 429 as rateLimited',
      () async {
        respond = (_) => http.Response('', 401);
        await expectLater(
          subject.upload(upload, 'tok'),
          throwsA(
            isA<StravaException>().having(
              (e) => e.failure,
              'failure',
              StravaFailure.authorizationRevoked,
            ),
          ),
        );

        respond = (_) => http.Response('', 429);
        await expectLater(
          subject.uploadStatus(1, 'tok'),
          throwsA(
            isA<StravaException>().having(
              (e) => e.failure,
              'failure',
              StravaFailure.rateLimited,
            ),
          ),
        );
      },
    );

    test('throws a failure to reach Strava as unavailable', () async {
      respond = (_) => throw http.ClientException('offline');

      await expectLater(
        subject.upload(upload, 'tok'),
        throwsA(
          isA<StravaException>().having(
            (e) => e.failure,
            'failure',
            StravaFailure.unavailable,
          ),
        ),
      );
    });
  });

  group('uploadStatus', () {
    test('gets the upload', () async {
      respond = (_) => http.Response('{"id": 5, "activity_id": 8}', 200);

      final status = await subject.uploadStatus(5, 'tok');

      expect(status, const StravaUploadStatus(id: 5, activityId: 8));
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/v3/uploads/5');
      expect(requests.single.headers['Authorization'], 'Bearer tok');
    });

    test('throws uploadFailed for any other status', () async {
      respond = (_) => http.Response('', 404);

      await expectLater(
        subject.uploadStatus(5, 'tok'),
        throwsA(isA<StravaException>().having((e) => e.status, 'status', 404)),
      );
    });

    test('throws unavailable for a body it cannot read', () async {
      respond = (_) => http.Response('{"no": "id"}', 200);

      await expectLater(
        subject.uploadStatus(5, 'tok'),
        throwsA(
          isA<StravaException>().having(
            (e) => e.failure,
            'failure',
            StravaFailure.unavailable,
          ),
        ),
      );
    });
  });

  group('updateActivity', () {
    test('puts the name and description', () async {
      await subject.updateActivity(
        42,
        name: 'Pull Day',
        description: 'Felt strong',
        accessToken: 'tok',
      );

      final request = requests.single;
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/v3/activities/42');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(request.body), {
        'name': 'Pull Day',
        'description': 'Felt strong',
      });
    });

    // An empty description clears it; leaving the key out would keep the
    // old one.
    test('clears the description with an empty one', () async {
      await subject.updateActivity(
        42,
        name: 'Pull Day',
        description: null,
        accessToken: 'tok',
      );

      expect(jsonDecode(requests.single.body), {
        'name': 'Pull Day',
        'description': '',
      });
    });

    test('throws uploadFailed when Strava refuses', () async {
      respond = (_) => http.Response('', 403);

      await expectLater(
        subject.updateActivity(
          42,
          name: 'n',
          description: null,
          accessToken: 'tok',
        ),
        throwsA(isA<StravaException>().having((e) => e.status, 'status', 403)),
      );
    });
  });

  group('callStravaFunction', () {
    test('calls the named callable with the data and returns its answer', () {
      final functions = _MockFunctions();
      final callable = _MockCallable();
      final result = _MockResult();
      when(() => functions.httpsCallable('stravaConnect')).thenReturn(callable);
      when(() => result.data).thenReturn({'athlete': null});
      when(() => callable.call<Object?>({'clientId': '42'}))
          .thenAnswer((_) async => result);

      expect(
        callStravaFunction(functions)('stravaConnect', {'clientId': '42'}),
        completion({'athlete': null}),
      );
      expect(stravaFunctionsRegion, 'us-central1');
    });
  });
}

class _MockFunctions extends Mock implements FirebaseFunctions;

class _MockCallable extends Mock implements HttpsCallable;

class _MockResult extends Mock implements HttpsCallableResult<Object?>;
