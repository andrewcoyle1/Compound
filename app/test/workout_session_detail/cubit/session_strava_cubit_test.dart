import 'package:compound/workout_session_detail/cubit/session_strava_cubit.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/analytics_recorder.dart';

const _uid = 'user-1';

WorkoutSessionModel _session(
  String id, {
  String author = _uid,
  int? stravaActivityId,
  int daysAgo = 0,
}) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day - daysAgo, 9);
  return WorkoutSessionModel(
    id: id,
    authorId: author,
    name: 'Push',
    dateCreated: start,
    dateModified: start,
    endedAt: start.add(const Duration(hours: 1)),
    stravaActivityId: stravaActivityId,
    exercises: const [],
  );
}

/// Ported from Swift's `WorkoutSessionStravaLinkTests` and the summary's
/// `StravaOffer` flow (the rule itself is `shouldOfferStrava`, tested in
/// strava_repository).
void main() {
  late InMemoryWorkoutSessionRepository sessions;
  late AnalyticsRecorder analytics;
  late StravaRepository strava;

  StravaRepository repository({StravaAthlete? athlete}) {
    final firestore = FakeFirebaseFirestore();
    return StravaRepository(
      firestore: firestore,
      api: FakeStravaApi(firestore: firestore, uid: _uid, athlete: athlete),
      sessions: sessions,
      store: InMemoryStravaAccountStore(),
      clientId: 'client',
      uploadContext: (_) async => (
        library: const <ExerciseModel>[],
        weightUnit: WeightUnitPreference.kilograms,
        distanceUnit: DistanceUnitPreference.kilometers,
      ),
    );
  }

  SessionStravaCubit build(
    String sessionId, {
    WorkoutSessionModel? session,
    bool summary = false,
  }) => SessionStravaCubit(
    sessions: sessions,
    analytics: analytics,
    uid: _uid,
    sessionId: sessionId,
    session: session,
    isWorkoutSummary: summary,
    strava: strava,
  )..started();

  setUp(() {
    analytics = AnalyticsRecorder();
  });

  group(SessionStravaCubit, () {
    test('the Strava link reads the stored session', () async {
      // The summary's copy predates the upload; the stored one has its id.
      final handed = _session('a');
      sessions = InMemoryWorkoutSessionRepository(
        sessions: [_session('a', stravaActivityId: 42)],
      );
      strava = repository();
      final cubit = build('a', session: handed);
      await pumpEventQueue();

      expect(
        cubit.state.link,
        Uri.parse('https://www.strava.com/activities/42'),
      );
      cubit.viewOnStravaPressed();
      expect(analytics.parameters('WorkoutSessionDetailView_ViewOnStrava'), {
        'session_id': 'a',
      });
      await cubit.close();
    });

    test('only the author sees the Strava link', () async {
      sessions = InMemoryWorkoutSessionRepository(
        sessions: [_session('b', author: 'someone', stravaActivityId: 7)],
      );
      strava = repository();
      final cubit = build('b');
      await pumpEventQueue();
      expect(cubit.state.link, isNull);
      await cubit.close();
    });

    test('the first finished workout is offered Strava once saved', () async {
      sessions = InMemoryWorkoutSessionRepository(sessions: const []);
      strava = repository();
      await strava.signIn(_uid);
      final finished = _session('first');
      final cubit = build('first', session: finished, summary: true);
      await pumpEventQueue();
      expect(cubit.state.offerId, 0);

      await sessions.saveSession(_uid, finished);
      await pumpEventQueue();

      expect(cubit.state.offerId, 1);
      expect(analytics.names, ['strava_offer_shown']);

      await cubit.offerAnswered(connect: false);
      expect(strava.offerAnswered, isTrue);
      expect(analytics.names.last, 'strava_offer_declined');

      // Another save does not offer again.
      await sessions.saveSession(_uid, _session('later'));
      await pumpEventQueue();
      expect(cubit.state.offerId, 1);
      await cubit.close();
    });

    test('accepting is recorded as the answer too', () async {
      sessions = InMemoryWorkoutSessionRepository(sessions: [_session('x')]);
      strava = repository();
      await strava.signIn(_uid);
      final cubit = build('x', session: _session('x'), summary: true);
      await pumpEventQueue();
      expect(cubit.state.offerId, 1);

      await cubit.offerAnswered(connect: true);

      expect(strava.offerAnswered, isTrue);
      expect(analytics.names.last, 'strava_offer_accepted');
      await cubit.close();
    });

    test('no offer after an earlier workout, when connected, or off the '
        'summary', () async {
      sessions = InMemoryWorkoutSessionRepository(
        sessions: [_session('old', daysAgo: 3), _session('new')],
      );
      strava = repository();
      await strava.signIn(_uid);
      final second = build('new', summary: true);

      sessions = InMemoryWorkoutSessionRepository(sessions: [_session('one')]);
      strava = repository(athlete: FakeStravaApi.stagingAthlete);
      await strava.signIn(_uid);
      final connected = build('one', summary: true);

      strava = repository();
      await strava.signIn(_uid);
      final history = build('one');
      await pumpEventQueue();

      expect(second.state.offerId, 0);
      expect(connected.state.offerId, 0);
      expect(history.state.offerId, 0);
      expect(analytics.names, isEmpty);
      await second.close();
      await connected.close();
      await history.close();
    });
  });
}
