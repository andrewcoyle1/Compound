// The smaller pieces: the redirect, the account store, the rules screens
// ask, the models, and the staging fake (Swift StravaManagerTests' redirect
// cases, StravaOfferTests, WorkoutSessionStravaLinkTests' link cases).
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/fixtures.dart';

Matcher _failure(StravaFailure failure) =>
    isA<StravaException>().having((e) => e.failure, 'failure', failure);

void main() {
  group('the redirect', () {
    test('asks Strava for upload and read permission', () {
      final uri = stravaAuthorizationUri('42');
      expect(uri.host, 'www.strava.com');
      expect(uri.path, '/oauth/mobile/authorize');
      expect(uri.queryParameters, {
        'client_id': '42',
        'redirect_uri': 'compoundstrava://localhost/exchange_token',
        'response_type': 'code',
        'approval_prompt': 'auto',
        'scope': 'activity:write,activity:read_all',
      });
    });

    test('yields the code when upload permission was granted', () {
      expect(
        stravaAuthorizationCode(
          Uri.parse(
            'compoundstrava://localhost/exchange_token'
            '?state=&code=abc&scope=read,activity:write',
          ),
        ),
        'abc',
      );
    });

    // Strava documents the granted scopes as comma- or space-delimited.
    test('reads a space-delimited grant', () {
      expect(
        stravaAuthorizationCode(
          Uri.parse(
            'compoundstrava://localhost/exchange_token'
            '?state=&code=abc&scope=read%20activity:write',
          ),
        ),
        'abc',
      );
    });

    // Strava's consent page lets the athlete untick the upload permission
    // and still redirects with a code.
    test('is refused without upload permission or a code', () {
      expect(
        () => stravaAuthorizationCode(
          Uri.parse(
            'compoundstrava://localhost/exchange_token?code=abc&scope=read',
          ),
        ),
        throwsA(_failure(StravaFailure.missingUploadPermission)),
      );
      expect(
        () => stravaAuthorizationCode(
          Uri.parse('compoundstrava://localhost/exchange_token?code=abc'),
        ),
        throwsA(_failure(StravaFailure.missingUploadPermission)),
      );
      expect(
        () => stravaAuthorizationCode(
          Uri.parse(
            'compoundstrava://localhost/exchange_token?error=access_denied',
          ),
        ),
        throwsA(_failure(StravaFailure.missingAuthCode)),
      );
      expect(
        () => stravaAuthorizationCode(
          Uri.parse('compoundstrava://localhost/exchange_token?code='),
        ),
        throwsA(_failure(StravaFailure.missingAuthCode)),
      );
    });

    test('the fake answers as an athlete agreeing to everything', () async {
      final redirect = await FakeStravaAuthorizer().authorize(
        stravaAuthorizationUri('42'),
        stravaCallbackScheme,
      );
      expect(redirect.scheme, 'compoundstrava');
      expect(stravaAuthorizationCode(redirect), 'staging-code');
    });
  });

  group('FileStravaAccountStore', () {
    late Directory directory;
    late FileStravaAccountStore store;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('strava_store');
      store = FileStravaAccountStore(Directory('${directory.path}/nested'));
    });
    tearDown(() => directory.deleteSync(recursive: true));

    test('keeps each account apart, across instances', () async {
      const state = StravaAccountState(
        athlete: StravaAthlete(
          id: 7,
          firstname: 'Alex',
          lastname: 'Runner',
          profile: 'https://a/p.jpg',
        ),
        pendingSessionIds: ['a', 'b'],
        offerAnswered: true,
      );

      await store.save('uid/1', state);
      final read = await FileStravaAccountStore(
        Directory('${directory.path}/nested'),
      ).load('uid/1');

      expect(read.athlete, state.athlete);
      expect(read.pendingSessionIds, ['a', 'b']);
      expect(read.offerAnswered, isTrue);
      expect((await store.load('other')).pendingSessionIds, isEmpty);
      expect(
        File('${directory.path}/nested/strava_uid%2F1.json').existsSync(),
        isTrue,
      );
    });

    test('reads a file it cannot read as the default', () async {
      await store.save('u', const StravaAccountState(offerAnswered: true));
      final file = File('${directory.path}/nested/strava_u.json')
        ..writeAsStringSync('[]');
      expect((await store.load('u')).offerAnswered, isFalse);

      file.writeAsStringSync('{"pending_session_ids": 1}');
      expect((await store.load('u')).offerAnswered, isFalse);

      file.writeAsStringSync('not json');
      expect((await store.load('u')).offerAnswered, isFalse);
    });
  });

  group('StravaAccountState', () {
    test('copyWith keeps, replaces and clears', () {
      const state = StravaAccountState(
        athlete: StravaAthlete(id: 1),
        pendingSessionIds: ['a'],
      );
      expect(state.copyWith().athlete, const StravaAthlete(id: 1));
      expect(state.copyWith(clearAthlete: true).athlete, isNull);
      expect(state.copyWith(pendingSessionIds: []).pendingSessionIds, isEmpty);
      expect(state.copyWith(offerAnswered: true).offerAnswered, isTrue);
    });
  });

  group('shouldOfferStrava', () {
    final at = DateTime.utc(2026, 2, 25);

    WorkoutSessionModel finished(
      String id, {
      String author = 'a1',
      bool restDay = false,
      bool deleted = false,
    }) => session(
      id: id,
      authorId: author,
      dateCreated: at,
      isRestDay: restDay,
      deletedAt: deleted ? at : null,
      exercises: const [],
    );

    bool offer(
      WorkoutSessionModel finished,
      List<WorkoutSessionModel> saved, {
      bool connected = false,
      bool answered = false,
    }) => shouldOfferStrava(
      finished: finished,
      savedSessions: saved,
      isStravaConnected: connected,
      hasAnswered: answered,
    );

    test('the first finished workout is the moment', () {
      final first = finished('w1');
      expect(offer(first, [first]), isTrue);
    });

    test('not before the workout has saved', () {
      expect(offer(finished('w1'), []), isFalse);
    });

    test('not after a second workout', () {
      final second = finished('w2');
      expect(offer(second, [finished('w1'), second]), isFalse);
    });

    test("rest days, deleted sessions and other people's do not count", () {
      final first = finished('w1');
      expect(
        offer(first, [
          finished('r1', restDay: true),
          finished('d1', deleted: true),
          finished('o1', author: 'someone-else'),
          first,
        ]),
        isTrue,
      );
    });

    test('never when Strava is connected or the offer was answered', () {
      final first = finished('w1');
      expect(offer(first, [first], connected: true), isFalse);
      expect(offer(first, [first], answered: true), isFalse);
    });

    test('a rest day is not a finished workout', () {
      final rest = finished('r1', restDay: true);
      expect(offer(rest, [rest]), isFalse);
    });

    test('a workout under way is not a finished workout', () {
      final running = session(running: true);
      expect(offer(running, [running]), isFalse);
    });
  });

  group('stravaActivityLink', () {
    test('links the stored session to its activity', () {
      expect(stravaActivityLink(session(), viewerId: 'author-1'), isNull);
      expect(
        stravaActivityLink(
          session(stravaActivityId: 42),
          viewerId: 'author-1',
        ).toString(),
        'https://www.strava.com/activities/42',
      );
    });

    test('only the author sees it', () {
      expect(
        stravaActivityLink(session(stravaActivityId: 42), viewerId: 'reader'),
        isNull,
      );
    });
  });

  group('StravaTotals', () {
    final activities = sampleStravaActivities(DateTime.utc(2026, 10, 15));

    test('adds up the span, start included and end left out', () {
      final totals = StravaTotals.of(
        activities,
        start: DateTime.utc(2026, 10, 12),
        end: DateTime.utc(2026, 10, 15),
      )!;
      expect(totals.count, 2);
      expect(totals.distanceMeters, 38600);
      expect(totals.movingTime, 5680);

      expect(
        StravaTotals.of(
          activities,
          start: DateTime.utc(2026, 10, 12),
          end: DateTime.utc(2026, 10, 14),
        )!.count,
        1,
      );
    });

    test('is nothing for an empty span', () {
      expect(
        StravaTotals.of(
          activities,
          start: DateTime.utc(2026),
          end: DateTime.utc(2026, 2),
        ),
        isNull,
      );
    });
  });

  group('models', () {
    test('an athlete is named by what it has', () {
      expect(
        const StravaAthlete(id: 1, firstname: 'Alex', lastname: '').name,
        'Alex',
      );
      expect(const StravaAthlete(id: 1).name, '');
      expect(
        const StravaAthlete(id: 1, firstname: 'A').hashCode,
        const StravaAthlete(id: 1, firstname: 'A').hashCode,
      );
      expect(
        StravaAthlete.fromJson(
          const StravaAthlete(id: 1, lastname: 'L').toJson(),
        ),
        const StravaAthlete(id: 1, lastname: 'L'),
      );
    });

    test('an upload status finds the activity it duplicates', () {
      const status = StravaUploadStatus(
        id: 1,
        error: 'compound-1 duplicate of activity 21234316',
      );
      expect(status.duplicateActivityId, 21234316);
      expect(const StravaUploadStatus(id: 1).duplicateActivityId, isNull);
      expect(
        const StravaUploadStatus(
          id: 1,
          error: 'Unrecognized exercise',
        ).duplicateActivityId,
        isNull,
      );
      expect(status.hashCode, isNot(const StravaUploadStatus(id: 1).hashCode));
    });

    test('an exception says what it is', () {
      expect(
        '${const StravaException(StravaFailure.uploadFailed, status: 500)}',
        'StravaException(uploadFailed, 500)',
      );
      expect(
        const StravaException(
          StravaFailure.processingFailed,
          reason: 'x',
          cause: 'y',
        ).toString(),
        'StravaException(processingFailed, x, y)',
      );
    });
  });

  group('FakeStravaApi', () {
    late FakeFirebaseFirestore firestore;

    setUp(() => firestore = FakeFirebaseFirestore());

    Future<List<String>> imported() async => [
      for (final document
          in (await firestore.collection('users/u/strava_activities').get())
              .docs)
        document.id,
    ];

    test(
      'connecting imports the activities, disconnecting drops them',
      () async {
        final api = FakeStravaApi(
          firestore: firestore,
          uid: 'u',
          activities: sampleStravaActivities(DateTime.utc(2026, 10, 15)),
        );
        expect(await api.connection(), isNull);
        await expectLater(
          api.accessToken(),
          throwsA(_failure(StravaFailure.notConnected)),
        );

        final result = await api.connect(clientId: '42', code: 'c');

        expect(result.athlete, FakeStravaApi.stagingAthlete);
        expect(await api.connection(), FakeStravaApi.stagingAthlete);
        expect((await api.accessToken()).accessToken, 'staging-access');
        expect(await imported(), ['1001', '1002']);
        final stored =
            (await firestore.doc('users/u/strava_activities/1001').get())
                .data()!;
        expect(stored['start_date'], isA<Timestamp>());

        await api.disconnect();

        expect(await api.connection(), isNull);
        expect(await imported(), isEmpty);
      },
    );

    test(
      'starts connected, with its activities, when given an athlete',
      () async {
        FakeStravaApi(
          firestore: firestore,
          uid: 'u',
          athlete: FakeStravaApi.stagingAthlete,
          activities: sampleStravaActivities(DateTime.utc(2026, 10, 15)),
        );
        await pumpEventQueue();

        expect(await imported(), ['1001', '1002']);
      },
    );

    test('answers a second upload of a workout as a duplicate', () async {
      final api = FakeStravaApi(firestore: firestore, uid: 'u');
      final upload = StravaUpload(
        name: 'n',
        description: null,
        externalId: 'compound-a',
        file: StravaStrengthFile.from(session(), const [])!,
      );

      final first = await api.upload(upload, 't');
      final again = await api.upload(upload, 't');

      expect(first.activityId, 1);
      expect(again.duplicateActivityId, 1);
      expect(
        await api.uploadStatus(3, 't'),
        const StravaUploadStatus(id: 3, activityId: 3),
      );
      await api.updateActivity(
        1,
        name: 'n',
        description: 'd',
        accessToken: 't',
      );
      expect(api.edits.single, (id: 1, name: 'n', description: 'd'));
      expect(api.uploads, hasLength(2));
    });

    test('runs the real repository end to end in staging', () async {
      final sessions = InMemoryWorkoutSessionRepository(sessions: [session()]);
      final api = FakeStravaApi(
        firestore: firestore,
        uid: 'author-1',
        activities: sampleStravaActivities(DateTime.now()),
      );
      final repository = StravaRepository(
        firestore: firestore,
        api: api,
        sessions: sessions,
        store: InMemoryStravaAccountStore(),
        clientId: 'staging',
        uploadContext: (_) async => (
          library: const <ExerciseModel>[],
          weightUnit: WeightUnitPreference.kilograms,
          distanceUnit: DistanceUnitPreference.kilometers,
        ),
      );
      await repository.signIn('author-1');
      expect(repository.isConnected, isFalse);

      await repository.connect(FakeStravaAuthorizer());
      expect(await repository.queueBackfill(), 1);
      await repository.syncPendingUploads();

      expect(
        (await sessions.session('author-1', 'session-1'))!.stravaActivityId,
        1,
      );
      expect(
        await repository.watchImportedActivities('author-1').first,
        hasLength(2),
      );
    });
  });
}
