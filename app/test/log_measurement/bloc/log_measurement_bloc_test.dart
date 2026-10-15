// LogMeasurementPresenterTests, one for one.
import 'package:bloc_test/bloc_test.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/log_measurement/log_measurement.dart';
import 'package:compound/progress/logic/body_metrics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const uid = 'user-1';
  final now = DateTime(2026, 10, 15, 9, 30);

  BodyMeasurementEntry entry(
    String id,
    BodyMeasurementKind kind,
    double cm, {
    int daysAgo = 0,
  }) => kind.update(
    BodyMeasurementEntry(
      id: id,
      authorId: uid,
      date: DateTime(2026, 10, 15 - daysAgo, 8),
      source: WeightSource.manual,
      dateCreated: DateTime(2026, 10, 15 - daysAgo, 8),
    ),
    cm,
  );

  late BodyRepository bodyRepository;
  late UserRepository userRepository;
  late AnalyticsRecorder analytics;

  void seed({
    List<BodyMeasurementEntry> measurements = const [],
    UserModel? user = const UserModel(userId: uid),
  }) {
    bodyRepository = InMemoryBodyRepository(measurements: measurements);
    userRepository = InMemoryUserRepository(users: {uid: ?user});
  }

  setUpAll(
    () => registerFallbackValue(entry('x', BodyMeasurementKind.neck, 1)),
  );

  /// Opens the screen and waits for it to be ready, as the form is.
  Future<void> open(LogMeasurementBloc bloc) async {
    bloc.add(const LogMeasurementStarted());
    await bloc.stream.firstWhere(
      (state) => state.status == LogMeasurementStatus.ready,
    );
  }

  setUp(() {
    seed();
    analytics = AnalyticsRecorder();
  });

  LogMeasurementBloc build(BodyMeasurementKind kind) => LogMeasurementBloc(
    bodyRepository: bodyRepository,
    userRepository: userRepository,
    analyticsRepository: analytics,
    uid: uid,
    kind: kind,
    now: () => now,
    newId: () => 'new-id',
  );

  Future<List<BodyMeasurementEntry>> stored() =>
      bodyRepository.watchMeasurements(uid).first;

  group(LogMeasurementBloc, () {
    blocTest<LogMeasurementBloc, LogMeasurementState>(
      'an unlogged measurement opens on its own defaults',
      build: () => build(BodyMeasurementKind.leftWrist),
      act: (bloc) => bloc.add(const LogMeasurementStarted()),
      verify: (bloc) {
        expect(bloc.state.status, LogMeasurementStatus.ready);
        expect(bloc.state.centimetres, 18);
        expect(bloc.state.inches, 7);
        expect(analytics.names.first, 'LogMeasurementView_Appear');
        expect(analytics.parameters('LogMeasurementView_Appear'), {
          'measurement': 'leftWrist',
        });
      },
    );

    blocTest<LogMeasurementBloc, LogMeasurementState>(
      'the latest reading becomes the starting value',
      setUp: () => seed(
        measurements: [
          entry('old', BodyMeasurementKind.waist, 90, daysAgo: 10),
          entry('new', BodyMeasurementKind.waist, 84, daysAgo: 1),
        ],
      ),
      build: () => build(BodyMeasurementKind.waist),
      act: (bloc) => bloc.add(const LogMeasurementStarted()),
      verify: (bloc) {
        expect(bloc.state.centimetres, 84);
        expect(bloc.state.centimetresTenths, 0);
        expect(bloc.state.inches, 33);
      },
    );

    blocTest<LogMeasurementBloc, LogMeasurementState>(
      "another measurement's history is ignored",
      setUp: () =>
          seed(measurements: [entry('w', BodyMeasurementKind.waist, 90)]),
      build: () => build(BodyMeasurementKind.neck),
      act: (bloc) => bloc.add(const LogMeasurementStarted()),
      verify: (bloc) => expect(bloc.state.centimetres, 40),
    );

    blocTest<LogMeasurementBloc, LogMeasurementState>(
      "the user's unit preference is applied",
      setUp: () => seed(
        user: const UserModel(
          userId: uid,
          submittedLengthUnitPreference: LengthUnitPreference.inches,
        ),
      ),
      build: () => build(BodyMeasurementKind.waist),
      act: (bloc) => bloc.add(const LogMeasurementStarted()),
      verify: (bloc) => expect(bloc.state.unit, LengthUnitPreference.inches),
    );

    blocTest<LogMeasurementBloc, LogMeasurementState>(
      'inches are converted to centimetres on save',
      build: () => build(BodyMeasurementKind.waist),
      act: (bloc) async {
        await open(bloc);
        bloc
          ..add(const LogMeasurementUnitChanged(LengthUnitPreference.inches))
          ..add(const LogMeasurementWholeChanged(32))
          ..add(const LogMeasurementSaveRequested());
      },
      verify: (bloc) async {
        expect(bloc.state.status, LogMeasurementStatus.saved);
        final saved = (await stored()).single;
        expect(saved.waistCircumference, closeTo(32 * 2.54, 1e-9));
        expect(saved.id, 'new-id');
        expect(saved.authorId, uid);
        expect(analytics.names, contains('LogMeasurementView_Save_Success'));
      },
    );

    blocTest<LogMeasurementBloc, LogMeasurementState>(
      'logging twice in a day updates the same entry',
      setUp: () =>
          seed(measurements: [entry('today', BodyMeasurementKind.neck, 38)]),
      build: () => build(BodyMeasurementKind.waist),
      act: (bloc) async {
        await open(bloc);
        bloc
          ..add(const LogMeasurementWholeChanged(81))
          ..add(const LogMeasurementSaveRequested());
      },
      verify: (_) async {
        final saved = (await stored()).single;
        expect(saved.id, 'today');
        expect(saved.waistCircumference, 81);
        // The neck logged earlier the same day survives.
        expect(saved.neckCircumference, 38);
      },
    );

    blocTest<LogMeasurementBloc, LogMeasurementState>(
      'logging on an empty day creates an entry',
      setUp: () => seed(
        measurements: [
          entry('old', BodyMeasurementKind.chest, 100, daysAgo: 5),
        ],
      ),
      build: () => build(BodyMeasurementKind.chest),
      act: (bloc) async {
        await open(bloc);
        bloc
          ..add(const LogMeasurementWholeChanged(104))
          ..add(const LogMeasurementSaveRequested());
      },
      verify: (_) async {
        final saved = (await stored()).firstWhere((e) => e.id == 'new-id');
        expect(saved.chestCircumference, 104);
        expect(saved.date, now);
        expect(saved.source, WeightSource.manual);
      },
    );

    blocTest<LogMeasurementBloc, LogMeasurementState>(
      'a failed save reports the error and stays open',
      setUp: () {
        final failing = MockBodyRepository();
        when(() => failing.watchMeasurements(uid))
            .thenAnswer((_) => Stream.value(const []));
        when(() => failing.saveMeasurement(any()))
            .thenThrow(Exception('offline'));
        bodyRepository = failing;
      },
      build: () => build(BodyMeasurementKind.neck),
      act: (bloc) async {
        await open(bloc);
        bloc.add(const LogMeasurementSaveRequested());
      },
      verify: (bloc) {
        expect(bloc.state.status, LogMeasurementStatus.failure);
        expect(bloc.state.isEditable, isTrue);
        expect(analytics.parameters('LogMeasurementView_Save_Fail'), {
          'measurement': 'neck',
          'error_description': 'Exception: offline',
        });
      },
    );

    blocTest<LogMeasurementBloc, LogMeasurementState>(
      'without a profile or readings it opens on the defaults',
      setUp: () {
        final failing = MockBodyRepository();
        when(() => failing.watchMeasurements(uid))
            .thenAnswer((_) => Stream.error(Exception('offline')));
        final users = MockUserRepository();
        when(() => users.watchUser(uid))
            .thenAnswer((_) => Stream.error(Exception('offline')));
        bodyRepository = failing;
        userRepository = users;
      },
      build: () => build(BodyMeasurementKind.hips),
      act: (bloc) => bloc.add(const LogMeasurementStarted()),
      verify: (bloc) {
        expect(bloc.state.status, LogMeasurementStatus.ready);
        expect(bloc.state.centimetres, 95);
        expect(bloc.state.unit, LengthUnitPreference.centimeters);
      },
    );

    blocTest<LogMeasurementBloc, LogMeasurementState>(
      'saving again while saving is ignored',
      build: () => build(BodyMeasurementKind.neck),
      seed: () => LogMeasurementState.initial(
        BodyMeasurementKind.neck,
        now,
      ).copyWith(status: LogMeasurementStatus.saving),
      act: (bloc) => bloc.add(const LogMeasurementSaveRequested()),
      expect: () => const <LogMeasurementState>[],
    );

    blocTest<LogMeasurementBloc, LogMeasurementState>(
      'a new day keeps the time the screen opened',
      build: () => build(BodyMeasurementKind.neck),
      act: (bloc) =>
          bloc.add(LogMeasurementDateChanged(DateTime(2026, 10, 12))),
      verify: (bloc) => expect(bloc.state.date, DateTime(2026, 10, 12, 9, 30)),
    );

    test('logs leaving once', () async {
      final bloc = build(BodyMeasurementKind.neck);
      await bloc.close();
      await bloc.close();
      expect(analytics.names, ['LogMeasurementView_Disappear']);
    });
  });

  group(LogMeasurementState, () {
    final state = LogMeasurementState.initial(BodyMeasurementKind.waist, now);

    test('turning a wheel keeps both units in step', () {
      final metric = state.withWhole(90).withTenths(5);
      expect(metric.centimetresValue, 90.5);
      expect(metric.inches, 35);
      expect(metric.inchesTenths, 6);
      final imperial = state
          .copyWith(unit: LengthUnitPreference.inches)
          .withWhole(40)
          .withTenths(2);
      expect(imperial.centimetresValue, closeTo(40.2 * 2.54, 1e-9));
      expect(imperial.centimetres, 102);
      expect(imperial.centimetresTenths, 1);
    });

    test('a reading off the wheel is kept on it', () {
      expect(state.withCentimetres(200).centimetres, 120);
      expect(state.withCentimetres(200).inches, 48);
    });
  });
}
