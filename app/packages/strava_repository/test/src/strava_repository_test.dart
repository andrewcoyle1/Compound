// The connection, its tokens and the upload queue (Swift
// StravaManagerTests), against a capturing StravaApi, the in-memory
// session repository and an in-memory account store.
//
// The Keychain migration of an older Swift build's refresh token has no
// Flutter counterpart and is not ported; see the slice's decisions.
import 'dart:async';

import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/contract.dart';
import '../helpers/fixtures.dart';

class _Fixture {
  new(this.repository, this.api, this.sessions, this.store, this.events);

  final StravaRepository repository;
  final CapturingStravaApi api;
  final InMemoryWorkoutSessionRepository sessions;
  final StravaAccountStore store;
  final List<(String, Map<String, Object>)> events;
}

const StravaUploadContext _kilograms = (
  library: <ExerciseModel>[],
  weightUnit: WeightUnitPreference.kilograms,
  distanceUnit: DistanceUnitPreference.kilometers,
);

StravaRepository _repository({
  required CapturingStravaApi api,
  required WorkoutSessionRepository sessions,
  required StravaAccountStore store,
  FakeFirebaseFirestore? firestore,
  int pollAttempts = 10,
  List<(String, Map<String, Object>)>? events,
  Future<StravaUploadContext> Function(String uid)? uploadContext,
}) => StravaRepository(
  firestore: firestore ?? FakeFirebaseFirestore(),
  api: api,
  sessions: sessions,
  store: store,
  clientId: 'client-id',
  uploadContext: uploadContext ?? (_) async => _kilograms,
  now: () => start,
  newId: () => 'ID',
  pollInterval: Duration.zero,
  pollAttempts: pollAttempts,
  onEvent: (name, parameters) => events?.add((name, parameters)),
);

/// A repository signed in as `author-1`. Signing in sends the queue, so a
/// session is only queued by what the test does next.
Future<_Fixture> _signedIn({
  List<WorkoutSessionModel> sessions = const [],
  CapturingStravaApi? api,
  StravaAccountStore? store,
  int pollAttempts = 10,
  Future<StravaUploadContext> Function(String uid)? uploadContext,
}) async {
  final capturing = api ?? CapturingStravaApi();
  final repository = InMemoryWorkoutSessionRepository(sessions: sessions);
  final accounts = store ?? InMemoryStravaAccountStore();
  final events = <(String, Map<String, Object>)>[];
  final subject = _repository(
    api: capturing,
    sessions: repository,
    store: accounts,
    pollAttempts: pollAttempts,
    events: events,
    uploadContext: uploadContext,
  );
  await subject.signIn('author-1');
  return _Fixture(subject, capturing, repository, accounts, events);
}

TypeMatcher<StravaException> _failure(StravaFailure failure) =>
    isA<StravaException>().having((e) => e.failure, 'failure', failure);

void main() {
  group('the connection', () {
    test('signing in reads the connection from the server', () async {
      final fixture = await _signedIn();

      expect(fixture.repository.isConnected, isTrue);
      expect(fixture.repository.athlete?.name, 'Alex Runner');
      expect(fixture.repository.userId, 'author-1');
    });

    // The connection belongs to the account: signing out forgets it here
    // and nothing more, and the last answer is remembered per account so
    // the next launch knows before the server answers.
    test('signing out forgets the connection here only', () async {
      final fixture = await _signedIn();

      fixture.repository.signOut();

      expect(fixture.repository.isConnected, isFalse);
      expect(fixture.repository.userId, isNull);
      expect(fixture.api.disconnectCount, 0);
      expect((await fixture.store.load('author-1')).athlete?.id, 7);
    });

    test('offline at sign-in, the remembered connection stands', () async {
      final store = InMemoryStravaAccountStore();
      await store.save(
        'author-1',
        const StravaAccountState(athlete: StravaAthlete(id: 3)),
      );
      final api = CapturingStravaApi()
        ..connectionError = const StravaException(StravaFailure.unavailable);

      final fixture = await _signedIn(api: api, store: store);

      expect(fixture.repository.athlete, const StravaAthlete(id: 3));
    });

    test('an account not connected on the server is not connected', () async {
      final fixture = await _signedIn(
        api: CapturingStravaApi()..athlete = null,
      );

      expect(fixture.repository.isConnected, isFalse);
    });

    test('disconnecting clears the connection and the queue', () async {
      final store = InMemoryStravaAccountStore();
      await store.save(
        'author-1',
        const StravaAccountState(pendingSessionIds: ['s']),
      );
      final fixture = await _signedIn(store: store);
      expect(fixture.repository.pendingSessionIds, ['s']);

      await fixture.repository.disconnect();

      expect(fixture.api.disconnectCount, 1);
      expect(fixture.repository.isConnected, isFalse);
      expect(fixture.repository.pendingSessionIds, isEmpty);
      expect((await store.load('author-1')).pendingSessionIds, isEmpty);
    });

    // The server did not disconnect, so neither does the app.
    test('a failed disconnect leaves the account connected', () async {
      final api = CapturingStravaApi()
        ..disconnectError = const StravaException(StravaFailure.unavailable);
      final fixture = await _signedIn(api: api);

      await expectLater(
        fixture.repository.disconnect(),
        throwsA(_failure(StravaFailure.unavailable)),
      );

      expect(fixture.repository.isConnected, isTrue);
    });

    test('connecting exchanges the code from the redirect', () async {
      final api = CapturingStravaApi()..athlete = null;
      final fixture = await _signedIn(api: api);
      final authorizer = FakeStravaAuthorizer();

      await fixture.repository.connect(authorizer);

      expect(authorizer.opened.single, stravaAuthorizationUri('client-id'));
      expect(api.connects.single, (
        clientId: 'client-id',
        code: 'staging-code',
        refreshToken: null,
      ));
      expect(fixture.repository.isConnected, isTrue);
      expect((await fixture.store.load('author-1')).athlete?.id, 7);
      // The token connect answered is used, not a fresh one.
      await fixture.repository.updateActivity(1, session());
      expect(api.issuedTokens, isEmpty);
    });

    test('a grant without upload permission does not connect', () async {
      final api = CapturingStravaApi()..athlete = null;
      final fixture = await _signedIn(api: api);

      await expectLater(
        fixture.repository.connect(FakeStravaAuthorizer(scope: 'read')),
        throwsA(_failure(StravaFailure.missingUploadPermission)),
      );

      expect(api.connects, isEmpty);
      expect(fixture.repository.isConnected, isFalse);
    });

    test('watchAthlete emits the athlete now and on each change', () async {
      final fixture = await _signedIn();
      final emitted = <int?>[];
      final subscription = fixture.repository.watchAthlete().listen(
        (athlete) => emitted.add(athlete?.id),
      );
      await pumpEventQueue();

      await fixture.repository.disconnect();
      await pumpEventQueue();
      await subscription.cancel();

      expect(emitted, [7, null]);
    });

    test('remembers the answer to the offer per account', () async {
      final fixture = await _signedIn();
      expect(fixture.repository.offerAnswered, isFalse);

      await fixture.repository.answerOffer();

      expect(fixture.repository.offerAnswered, isTrue);
      expect((await fixture.store.load('author-1')).offerAnswered, isTrue);
      expect((await fixture.store.load('someone-else')).offerAnswered, isFalse);
    });

    test('a sign-out during sign-in wins', () async {
      final store = _SlowStore();
      final subject = _repository(
        api: CapturingStravaApi(),
        sessions: InMemoryWorkoutSessionRepository(sessions: []),
        store: store,
      );

      final signingIn = subject.signIn('author-1');
      subject.signOut();
      store.release.complete();
      await signingIn;

      expect(subject.userId, isNull);
      expect(subject.isConnected, isFalse);
    });
  });

  group('tokens', () {
    // A token is asked for once and reused until it is within a minute of
    // expiring.
    test('a token is reused until it nearly expires', () async {
      final fixture = await _signedIn();
      await fixture.repository.updateActivity(1, session());
      await fixture.repository.updateActivity(1, session());
      expect(fixture.api.issuedTokens, ['token-1']);

      final shortLived = CapturingStravaApi()..tokenLifetime = 30;
      final other = await _signedIn(api: shortLived);
      await other.repository.updateActivity(1, session());
      await other.repository.updateActivity(1, session());
      expect(shortLived.issuedTokens, ['token-1', 'token-2']);
    });

    // A 401 gets one fresh token and one retry.
    test('a rejected token is replaced once and the request retried', () async {
      final api = CapturingStravaApi()..rejectedTokens = {'token-1'};
      final fixture = await _signedIn(api: api);

      await fixture.repository.updateActivity(1, session());

      expect(api.issuedTokens, ['token-1', 'token-2']);
      expect(api.updates, hasLength(1));
      expect(fixture.repository.isConnected, isTrue);
    });

    // Strava refusing a fresh token too means the athlete revoked Compound.
    test('a token refused twice disconnects', () async {
      final api = CapturingStravaApi()..rejectedTokens = {'token-1', 'token-2'};
      final fixture = await _signedIn(api: api);

      await expectLater(
        fixture.repository.updateActivity(1, session()),
        throwsA(_failure(StravaFailure.notConnected)),
      );

      expect(fixture.repository.isConnected, isFalse);
      expect((await fixture.store.load('author-1')).athlete, isNull);
    });

    test('no connection on the server disconnects', () async {
      final fixture = await _signedIn();
      fixture.api.athlete = null;

      await expectLater(
        fixture.repository.updateActivity(1, session()),
        throwsA(_failure(StravaFailure.notConnected)),
      );

      expect(fixture.repository.isConnected, isFalse);
    });

    test('any other failure passes through and keeps the connection', () async {
      final fixture = await _signedIn();
      await expectLater(
        fixture.repository.withAccessToken<void>(
          (_) => throw const StravaException(StravaFailure.rateLimited),
        ),
        throwsA(_failure(StravaFailure.rateLimited)),
      );
      expect(fixture.repository.isConnected, isTrue);
    });

    test('an edit sends the name and description', () async {
      final fixture = await _signedIn();

      await fixture.repository.updateActivity(
        42,
        session(name: 'Pull Day', notes: 'Felt strong'),
      );

      final update = fixture.api.updates.single;
      expect(update.id, 42);
      expect(update.name, 'Pull Day');
      expect(update.description, startsWith('Felt strong\n\n'));
    });
  });

  group('sending one workout', () {
    // The external id is what makes a second upload of the same session a
    // duplicate rather than a second activity.
    test('is sent with its name, description and session id', () async {
      final fixture = await _signedIn();

      final outcome = await fixture.repository.upload(
        session(name: 'Upper Body A', notes: 'Felt strong'),
      );

      final upload = fixture.api.uploaded.single;
      expect(upload.name, 'Upper Body A');
      expect(upload.description, startsWith('Felt strong'));
      expect(upload.externalId, 'compound-session-1');
      expect(outcome, const StravaLinked(42));
      expect(outcome.hashCode, const StravaLinked(42).hashCode);
      expect('$outcome', 'StravaLinked(42)');
    });

    test('a workout with no completed set has nothing to send', () async {
      final fixture = await _signedIn();
      final workout = session(
        exercises: [
          exercise(sets: [row('a', completed: false)]),
        ],
      );

      expect(
        await fixture.repository.upload(workout),
        isA<StravaNothingToSend>(),
      );
      expect(fixture.api.uploaded, isEmpty);
    });

    test('a processing upload is polled until its activity exists', () async {
      final api = CapturingStravaApi()
        ..statuses = [
          const StravaUploadStatus(id: 7),
          const StravaUploadStatus(id: 7),
          const StravaUploadStatus(id: 7, activityId: 99),
        ];
      final fixture = await _signedIn(api: api);

      expect(
        await fixture.repository.upload(session()),
        const StravaLinked(99),
      );
      expect(api.polledIds, [7, 7]);
    });

    // The second upload of a session is refused as a duplicate of the
    // first, which is the activity it already became.
    test('a duplicate upload answers the existing activity', () async {
      final api = CapturingStravaApi()
        ..statuses = [
          const StravaUploadStatus(
            id: 7,
            error: 'compound-session-1 duplicate of activity 21234316',
          ),
        ];
      final fixture = await _signedIn(api: api);

      expect(
        await fixture.repository.upload(session()),
        const StravaLinked(21234316),
      );
    });

    test("a processing error is thrown with Strava's reason", () async {
      final api = CapturingStravaApi()
        ..statuses = [
          const StravaUploadStatus(id: 7, error: 'Unrecognized exercise'),
        ];
      final fixture = await _signedIn(api: api);

      await expectLater(
        fixture.repository.upload(session()),
        throwsA(
          _failure(StravaFailure.processingFailed)
              .having((e) => e.reason, 'reason', 'Unrecognized exercise'),
        ),
      );
    });

    test('an upload still processing after the wait is processing', () async {
      final api = CapturingStravaApi()
        ..statuses = [const StravaUploadStatus(id: 7)];
      final fixture = await _signedIn(api: api, pollAttempts: 3);

      expect(
        await fixture.repository.upload(session()),
        isA<StravaProcessing>(),
      );
      expect(api.polledIds, hasLength(3));
    });

    test('needs someone signed in', () async {
      final fixture = await _signedIn();
      fixture.repository.signOut();

      expect(() => fixture.repository.upload(session()), throwsStateError);
    });

    test('a test upload is a one-set workout with its own id', () async {
      final fixture = await _signedIn();

      await fixture.repository.uploadTestActivity();

      final upload = fixture.api.uploaded.single;
      expect(upload.name, 'Compound Test Upload');
      expect(upload.externalId, 'compound-test-ID');
      expect(
        upload.description,
        'Test upload from Compound — safe to delete.\n\n'
        'Barbell Bench Press: 60 kg × 10',
      );
      expect(upload.file.elapsedTime, 1800);
      expect(upload.file.sets.single.exerciseType, 'BARBELL_BENCH_PRESS');
    });
  });

  group('the queue', () {
    // A finished workout goes up and its session is stamped with the
    // activity.
    test('a queued workout is sent and linked', () async {
      final workout = session();
      final fixture = await _signedIn(sessions: [workout]);

      await fixture.repository.queueUpload(workout);

      expect(fixture.repository.pendingSessionIds, isEmpty);
      expect(
        (await fixture.sessions.session(
          'author-1',
          'session-1',
        ))!.stravaActivityId,
        42,
      );
    });

    // The session just saved may not be readable yet; it is sent from the
    // copy given, and the link is lost if the session never arrives.
    test('a just-finished workout is sent from the copy given', () async {
      final fixture = await _signedIn();

      await fixture.repository.queueUpload(session());

      expect(fixture.api.uploaded.single.externalId, 'compound-session-1');
      expect(fixture.repository.pendingSessionIds, isEmpty);
    });

    // Offline at the gym: the workout stays queued, across launches, and
    // goes at the next sign-in.
    test('a failed upload stays queued across launches', () async {
      final workout = session();
      final store = InMemoryStravaAccountStore();
      final offline = CapturingStravaApi()
        ..uploadErrors = [const StravaException(StravaFailure.unavailable)];
      final first = await _signedIn(
        sessions: [workout],
        api: offline,
        store: store,
      );

      await first.repository.queueUpload(workout);
      expect(first.repository.pendingSessionIds, ['session-1']);
      expect(first.events.single.$1, 'strava_upload_error');

      final relaunch = await _signedIn(sessions: [workout], store: store);

      expect(
        [for (final upload in relaunch.api.uploaded) upload.externalId],
        ['compound-session-1'],
      );
      expect(relaunch.repository.pendingSessionIds, isEmpty);
    });

    // Over Strava's limit, every later upload would fail too: the queue
    // stops and keeps them all.
    test("hitting Strava's limit stops the queue and keeps it", () async {
      final api = CapturingStravaApi()
        ..uploadErrors = [const StravaException(StravaFailure.rateLimited)];
      final fixture = await _queued(['a', 'b'], api: api);

      await fixture.repository.syncPendingUploads();

      expect(fixture.repository.pendingSessionIds, ['a', 'b']);
      expect(api.uploaded, isEmpty);
    });

    // A workout Strava will never take is dropped rather than retried
    // forever, and the rest go on.
    test('a workout Strava refuses is dropped and the rest sent', () async {
      final api = CapturingStravaApi()
        ..uploadErrors = [
          const StravaException(StravaFailure.uploadFailed, status: 400),
        ];
      final fixture = await _queued(['a', 'b'], api: api);

      await fixture.repository.syncPendingUploads();

      expect(fixture.repository.pendingSessionIds, isEmpty);
      expect([for (final u in api.uploaded) u.externalId], ['compound-b']);
      expect(fixture.events.single.$1, 'strava_upload_rejected');
      expect(fixture.events.single.$2, {'status': 400});
    });

    test('a server error stops the queue', () async {
      final api = CapturingStravaApi()
        ..uploadErrors = [
          const StravaException(StravaFailure.uploadFailed, status: 503),
        ];
      final fixture = await _queued(['a', 'b'], api: api);

      await fixture.repository.syncPendingUploads();

      expect(fixture.repository.pendingSessionIds, ['a', 'b']);
    });

    test('a workout Strava cannot process is dropped', () async {
      final api = CapturingStravaApi()
        ..statuses = [
          const StravaUploadStatus(id: 1, error: 'Unrecognized exercise'),
          const StravaUploadStatus(id: 2, activityId: 5),
        ];
      final fixture = await _queued(['a', 'b'], api: api);

      await fixture.repository.syncPendingUploads();

      expect(fixture.repository.pendingSessionIds, isEmpty);
      expect(fixture.events.single.$1, 'strava_upload_rejected');
      expect(fixture.events.single.$2, {'reason': 'Unrecognized exercise'});
    });

    // Still processing: kept, because sending again answers the activity
    // as a duplicate.
    test('a workout still processing stays queued', () async {
      final workout = session();
      final api = CapturingStravaApi()
        ..statuses = [const StravaUploadStatus(id: 7)];
      final fixture = await _signedIn(
        sessions: [workout],
        api: api,
        pollAttempts: 1,
      );

      await fixture.repository.queueUpload(workout);

      expect(fixture.repository.pendingSessionIds, ['session-1']);
    });

    test('nothing is queued without a connection', () async {
      final fixture = await _signedIn(
        api: CapturingStravaApi()..athlete = null,
      );

      await fixture.repository.queueUpload(session());

      expect(fixture.repository.pendingSessionIds, isEmpty);
      expect(fixture.api.uploaded, isEmpty);
    });

    test('a workout queued twice is queued once', () async {
      final api = CapturingStravaApi()
        ..statuses = [const StravaUploadStatus(id: 7)];
      final fixture = await _signedIn(api: api, pollAttempts: 0);

      await fixture.repository.queueUpload(session());
      await fixture.repository.queueUpload(session());

      expect(fixture.repository.pendingSessionIds, ['session-1']);
    });

    test('deleted, linked and empty sessions leave the queue unsent', () async {
      final fixture = await _queued(
        ['deleted', 'linked', 'empty', 'missing'],
        sessions: [
          session(id: 'deleted', deletedAt: start),
          session(id: 'linked', stravaActivityId: 1),
          session(
            id: 'empty',
            exercises: [
              exercise(sets: [row('a', completed: false)]),
            ],
          ),
        ],
      );

      await fixture.repository.syncPendingUploads();

      expect(fixture.api.uploaded, isEmpty);
      // A session not loaded yet stays for the next sync.
      expect(fixture.repository.pendingSessionIds, ['missing']);
    });

    test('a session that cannot be read stays queued', () async {
      final store = InMemoryStravaAccountStore();
      await store.save(
        'author-1',
        const StravaAccountState(pendingSessionIds: ['a']),
      );
      final subject = _repository(
        api: CapturingStravaApi(),
        sessions: _UnreadableSessions(),
        store: store,
      );

      await subject.signIn('author-1');

      expect(subject.pendingSessionIds, ['a']);
    });

    test('a context that cannot be loaded stops the queue', () async {
      final events = <(String, Map<String, Object>)>[];
      final store = InMemoryStravaAccountStore();
      await store.save(
        'author-1',
        const StravaAccountState(pendingSessionIds: ['a']),
      );
      final subject = _repository(
        api: CapturingStravaApi(),
        sessions: InMemoryWorkoutSessionRepository(
          sessions: [session(id: 'a')],
        ),
        store: store,
        events: events,
        uploadContext: (_) async => throw StateError('no user'),
      );

      await subject.signIn('author-1');

      expect(subject.pendingSessionIds, ['a']);
      expect(events.single.$1, 'strava_upload_error');
    });

    test('one sync at a time', () async {
      final release = Completer<void>();
      final fixture = await _queued(['a']);
      final api = fixture.api;
      var contextLoads = 0;
      final subject = _repository(
        api: api,
        sessions: fixture.sessions,
        store: fixture.store,
        uploadContext: (_) async {
          contextLoads++;
          await release.future;
          return _kilograms;
        },
      );
      final signingIn = subject.signIn('author-1');
      await pumpEventQueue();
      expect(subject.isSyncingUploads, isTrue);

      await subject.syncPendingUploads();
      release.complete();
      await signingIn;

      expect(contextLoads, 1);
      expect(subject.isSyncingUploads, isFalse);
    });

    test('a sign-out stops the queue', () async {
      final release = Completer<void>();
      final fixture = await _queued(['a', 'b']);
      final subject = _repository(
        api: fixture.api,
        sessions: fixture.sessions,
        store: fixture.store,
        uploadContext: (_) async {
          await release.future;
          return _kilograms;
        },
      );
      final signingIn = subject.signIn('author-1');
      await pumpEventQueue();

      subject.signOut();
      release.complete();
      await signingIn;

      // Sent, but left queued for that account: its next sync links the
      // activity through Strava's duplicate answer.
      expect(fixture.api.uploaded, hasLength(1));
      expect((await fixture.store.load('author-1')).pendingSessionIds, [
        'a',
        'b',
      ]);
    });

    test('a lost link costs only the link', () async {
      final fixture = await _signedIn(sessions: [session(id: 'other')]);

      await fixture.repository.queueUpload(session(id: 'not-stored'));

      expect(fixture.repository.pendingSessionIds, isEmpty);
    });
  });

  group('past workouts', () {
    // Finished, own, not rest days, not deleted, not already on Strava,
    // with something to send: oldest first so Strava's feed fills in
    // order.
    test('the ones Strava could take are queued, oldest first', () async {
      final api = CapturingStravaApi()..athlete = null;
      final fixture = await _signedIn(
        api: api,
        sessions: [
          session(id: 'newer', dateCreated: start.add(const Duration(days: 1))),
          session(id: 'older'),
          session(id: 'linked', stravaActivityId: 1),
          session(id: 'deleted', deletedAt: start),
          session(id: 'rest', isRestDay: true),
          session(id: 'running', running: true),
          session(id: 'friend', authorId: 'someone-else'),
          session(
            id: 'empty',
            exercises: [
              exercise(sets: [row('a', completed: false)]),
            ],
          ),
        ],
      );

      expect(
        [for (final s in await fixture.repository.backfillCandidates()) s.id],
        ['older', 'newer'],
      );
      expect(await fixture.repository.queueBackfill(), 2);
      expect(fixture.repository.pendingSessionIds, ['older', 'newer']);
      expect(await fixture.repository.queueBackfill(), 0);
    });

    test('there are none while signed out', () async {
      final fixture = await _signedIn(sessions: [session()]);
      fixture.repository.signOut();

      expect(await fixture.repository.backfillCandidates(), isEmpty);
    });
  });

  group('edits', () {
    // The description lists the sets as well as the notes, so a saved edit
    // goes to Strava. The id is read from the stored session.
    test('a saved edit is sent to the stored activity', () async {
      final fixture = await _signedIn(
        sessions: [session(stravaActivityId: 42)],
      );

      final sent = await fixture.repository.pushEdit(
        session(notes: 'Felt strong'),
      );

      expect(sent, isTrue);
      expect(fixture.api.updates.single.id, 42);
      expect(fixture.api.updates.single.description, startsWith('Felt strong'));
    });

    test('a session not on Strava sends nothing', () async {
      final fixture = await _signedIn(sessions: [session()]);

      expect(await fixture.repository.pushEdit(session(notes: 'x')), isFalse);
      expect(fixture.api.updates, isEmpty);
    });

    test('nothing is sent without a connection', () async {
      final fixture = await _signedIn(
        api: CapturingStravaApi()..athlete = null,
        sessions: [session(stravaActivityId: 42)],
      );

      expect(await fixture.repository.pushEdit(session()), isFalse);
    });
  });

  group('imported activities', () {
    test('are read newest first, skipping one that does not decode', () async {
      final firestore = FakeFirebaseFirestore();
      final errors = <String>[];
      final subject = StravaRepository(
        firestore: firestore,
        api: CapturingStravaApi(),
        sessions: InMemoryWorkoutSessionRepository(sessions: []),
        store: InMemoryStravaAccountStore(),
        clientId: 'client-id',
        uploadContext: (_) async => _kilograms,
        onDecodeError: (path, _, _) => errors.add(path),
      );
      final activities = firestore.collection('users/u/strava_activities');
      await activities
          .doc('12345678902')
          .set(storedFixture('strava_imported_activity', 'minimal'));
      await activities
          .doc('12345678901')
          .set(storedFixture('strava_imported_activity', 'full'));
      await activities.doc('bad').set({'id': 'bad'});
      await firestore
          .collection('users/other/strava_activities')
          .doc('1')
          .set(storedFixture('strava_imported_activity', 'full'));

      final read = await subject.watchImportedActivities('u').first;

      expect([for (final a in read) a.name], ['Morning Run', 'Evening Ride']);
      expect(read.first.startDate, DateTime.utc(2026, 10, 11, 6, 30));
      expect(read.first.averageHeartrate, 151.25);
      expect(errors, ['users/u/strava_activities/bad']);
    });

    test('logs an activity that does not decode by default', () async {
      final firestore = FakeFirebaseFirestore();
      final subject = _repository(
        api: CapturingStravaApi(),
        sessions: InMemoryWorkoutSessionRepository(sessions: []),
        store: InMemoryStravaAccountStore(),
        firestore: firestore,
      );
      await firestore.doc('users/u/strava_activities/bad').set({'id': 1});

      expect(await subject.watchImportedActivities('u').first, isEmpty);
    });
  });

  test('logs queue events by default', () async {
    final store = InMemoryStravaAccountStore();
    await store.save(
      'author-1',
      const StravaAccountState(pendingSessionIds: ['a']),
    );
    final subject = StravaRepository(
      firestore: FakeFirebaseFirestore(),
      api: CapturingStravaApi()
        ..uploadErrors = [const StravaException(StravaFailure.rateLimited)],
      sessions: InMemoryWorkoutSessionRepository(sessions: [session(id: 'a')]),
      store: store,
      clientId: 'client-id',
      uploadContext: (_) async => _kilograms,
    );

    await subject.signIn('author-1');

    expect(subject.pendingSessionIds, ['a']);
  });
}

/// A repository signed in as `author-1` with [ids] queued and not yet sent,
/// each a stored session unless [sessions] says otherwise.
Future<_Fixture> _queued(
  List<String> ids, {
  CapturingStravaApi? api,
  List<WorkoutSessionModel>? sessions,
}) async {
  final capturing = (api ?? CapturingStravaApi())..athlete = null;
  final store = InMemoryStravaAccountStore();
  await store.save('author-1', StravaAccountState(pendingSessionIds: ids));
  // Signing in while not connected loads the queue without sending it.
  final fixture = await _signedIn(
    api: capturing,
    store: store,
    sessions: sessions ?? [for (final id in ids) session(id: id)],
  );
  capturing.athlete = const StravaAthlete(id: 7);
  await fixture.repository.refreshConnection();
  return fixture;
}

class _SlowStore extends InMemoryStravaAccountStore {
  final release = Completer<void>();

  @override
  Future<StravaAccountState> load(String uid) async {
    await release.future;
    return await super.load(uid);
  }
}

class _UnreadableSessions extends InMemoryWorkoutSessionRepository {
  new() : super(sessions: []);

  @override
  Future<WorkoutSessionModel?> session(String uid, String id) async =>
      throw StateError('offline');
}
