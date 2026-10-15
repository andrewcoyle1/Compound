import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository;

class _FakeEntry extends Fake implements BodyMeasurementEntry;

class _FakeEvent extends Fake implements LoggableEvent;

void main() {
  const uid = 'me';
  // Opened at 7:45:30pm on Thursday 15 October 2026.
  final now = DateTime(2026, 10, 15, 19, 45, 30);

  late BodyRepository bodyRepository;
  late UserRepository userRepository;
  late AnalyticsRepository analyticsRepository;

  UserModel user({double? weightKg, WeightUnitPreference? unit}) => UserModel(
    userId: uid,
    creationDate: DateTime(2026),
    submittedWeightKilograms: weightKg,
    submittedWeightUnitPreference: unit,
  );

  BodyMeasurementEntry weighIn(
    DateTime date,
    double? kg, {
    DateTime? deletedAt,
  }) => BodyMeasurementEntry(
    id: 'w-$date',
    authorId: uid,
    weightKg: kg,
    date: date,
    source: WeightSource.manual,
    dateCreated: date,
    deletedAt: deletedAt,
  );

  setUpAll(() {
    registerFallbackValue(_FakeEntry());
    registerFallbackValue(_FakeEvent());
  });

  setUp(() {
    bodyRepository = MockBodyRepository();
    userRepository = MockUserRepository();
    analyticsRepository = _MockAnalyticsRepository();
    when(() => bodyRepository.watchMeasurements(uid))
        .thenAnswer((_) => Stream.value(const []));
    when(() => userRepository.watchUser(uid))
        .thenAnswer((_) => Stream.value(user()));
    when(() => bodyRepository.saveMeasurement(any())).thenAnswer((_) async {});
    when(() => userRepository.updateUserFields(any(), any()))
        .thenAnswer((_) async {});
  });

  LogWeightBloc build() => LogWeightBloc(
    bodyRepository: bodyRepository,
    userRepository: userRepository,
    analyticsRepository: analyticsRepository,
    uid: uid,
    now: () => now,
    newId: () => 'NEW-ID',
  );

  /// Ready, at Swift's defaults: 70.0 kg, 154.0 lb, kilograms.
  LogWeightState ready() =>
      LogWeightState(date: now, status: LogWeightStatus.ready);

  group(LogWeightBloc, () {
    test('starts loading at the moment it opened, with Swift defaults', () {
      expect(build().state, LogWeightState(date: now));
      expect(build().state.weightKg, 70);
    });

    group(LogWeightStarted, () {
      blocTest<LogWeightBloc, LogWeightState>(
        'keeps the defaults with no weigh-in and no profile weight, and '
        'logs the screen',
        build: build,
        act: (bloc) => bloc.add(const LogWeightStarted()),
        expect: () => [ready()],
        verify: (_) {
          final event =
              verify(() => analyticsRepository.trackScreenView(captureAny()))
                      .captured
                      .single
                  as LoggableEvent;
          expect(event.eventName, 'LogWeightView_Appear');
        },
      );

      blocTest<LogWeightBloc, LogWeightState>(
        'opens on the latest weigh-in, skipping deleted entries and ones '
        'without a weight, in the profile unit',
        setUp: () {
          when(() => userRepository.watchUser(uid)).thenAnswer(
            (_) => Stream.value(
              user(weightKg: 90, unit: WeightUnitPreference.pounds),
            ),
          );
          when(() => bodyRepository.watchMeasurements(uid)).thenAnswer(
            (_) => Stream.value([
              weighIn(DateTime(2026, 10, 12), 81.2),
              weighIn(DateTime(2026, 10, 14), 82.44),
              weighIn(DateTime(2026, 10, 13), 80),
              weighIn(DateTime(2026, 10, 15), null),
              weighIn(DateTime(2026, 10, 15), 99, deletedAt: now),
            ]),
          );
        },
        build: build,
        act: (bloc) => bloc.add(const LogWeightStarted()),
        // 82.44 kg × 2.20462 = 181.7484… lb.
        expect: () => [
          ready().copyWith(
            unit: WeightUnitPreference.pounds,
            kilograms: 82,
            kilogramsTenths: 4,
            pounds: 181,
            poundsTenths: 7,
          ),
        ],
      );

      blocTest<LogWeightBloc, LogWeightState>(
        'falls back to the onboarding weight',
        setUp: () =>
            when(() => userRepository.watchUser(uid))
                .thenAnswer((_) => Stream.value(user(weightKg: 64.96))),
        build: build,
        act: (bloc) => bloc.add(const LogWeightStarted()),
        // 64.96 rounds to 65.0; 143.21… lb.
        expect: () => [
          ready().copyWith(
            kilograms: 65,
            kilogramsTenths: 0,
            pounds: 143,
            poundsTenths: 2,
          ),
        ],
      );

      blocTest<LogWeightBloc, LogWeightState>(
        'keeps a weight past the wheels on them',
        setUp: () =>
            when(() => userRepository.watchUser(uid))
                .thenAnswer((_) => Stream.value(user(weightKg: 25.3))),
        build: build,
        act: (bloc) => bloc.add(const LogWeightStarted()),
        // 25.3 kg is 55.8 lb: 30.3 kg and 66.8 lb on the wheels.
        expect: () => [
          ready().copyWith(
            kilograms: 30,
            kilogramsTenths: 3,
            pounds: 66,
            poundsTenths: 8,
          ),
        ],
      );

      blocTest<LogWeightBloc, LogWeightState>(
        'opens at the defaults when neither can be read',
        setUp: () {
          when(() => userRepository.watchUser(uid))
              .thenAnswer((_) => Stream.error(Exception('offline')));
          when(() => bodyRepository.watchMeasurements(uid))
              .thenAnswer((_) => Stream.error(Exception('offline')));
        },
        build: build,
        act: (bloc) => bloc.add(const LogWeightStarted()),
        expect: () => [ready()],
      );
    });

    blocTest<LogWeightBloc, LogWeightState>(
      'a new day keeps the time of day it opened at',
      build: build,
      seed: ready,
      act: (bloc) => bloc.add(LogWeightDateChanged(DateTime(2026, 10, 3))),
      expect: () => [ready().copyWith(date: DateTime(2026, 10, 3, 19, 45, 30))],
    );

    blocTest<LogWeightBloc, LogWeightState>(
      'switching unit changes only the unit',
      build: build,
      seed: ready,
      act: (bloc) =>
          bloc.add(const LogWeightUnitChanged(WeightUnitPreference.pounds)),
      expect: () => [ready().copyWith(unit: WeightUnitPreference.pounds)],
    );

    group('turning a wheel converts to the other unit', () {
      blocTest<LogWeightBloc, LogWeightState>(
        'kilograms',
        build: build,
        seed: ready,
        act: (bloc) => bloc
          ..add(const LogWeightWholeChanged(82))
          ..add(const LogWeightTenthsChanged(5)),
        // 82.0 kg = 180.78 lb; 82.5 kg = 181.88 lb.
        expect: () => [
          ready().copyWith(kilograms: 82, pounds: 180, poundsTenths: 8),
          ready().copyWith(
            kilograms: 82,
            kilogramsTenths: 5,
            pounds: 181,
            poundsTenths: 9,
          ),
        ],
      );

      blocTest<LogWeightBloc, LogWeightState>(
        'pounds',
        build: build,
        seed: () => ready().copyWith(unit: WeightUnitPreference.pounds),
        act: (bloc) => bloc
          ..add(const LogWeightWholeChanged(200))
          ..add(const LogWeightTenthsChanged(3)),
        // 200.0 lb = 90.718 kg; 200.3 lb = 90.854 kg.
        expect: () => [
          ready().copyWith(
            unit: WeightUnitPreference.pounds,
            pounds: 200,
            kilograms: 90,
            kilogramsTenths: 7,
          ),
          ready().copyWith(
            unit: WeightUnitPreference.pounds,
            pounds: 200,
            poundsTenths: 3,
            kilograms: 90,
            kilogramsTenths: 9,
          ),
        ],
      );
    });

    group(LogWeightSaveRequested, () {
      blocTest<LogWeightBloc, LogWeightState>(
        'saves a manual weigh-in, then the profile weight and unit',
        build: build,
        seed: () => ready().copyWith(
          date: DateTime(2026, 10, 14, 19, 45, 30),
          kilograms: 82,
          kilogramsTenths: 4,
        ),
        act: (bloc) => bloc.add(const LogWeightSaveRequested()),
        expect: () => [
          ready().copyWith(
            date: DateTime(2026, 10, 14, 19, 45, 30),
            kilograms: 82,
            kilogramsTenths: 4,
            status: LogWeightStatus.saving,
          ),
          ready().copyWith(
            date: DateTime(2026, 10, 14, 19, 45, 30),
            kilograms: 82,
            kilogramsTenths: 4,
            status: LogWeightStatus.saved,
          ),
        ],
        verify: (_) {
          final entry =
              verify(() => bodyRepository.saveMeasurement(captureAny()))
                      .captured
                      .single
                  as BodyMeasurementEntry;
          expect(entry.toFirestore(), {
            'id': 'NEW-ID',
            'author_id': uid,
            'weight_kg': 82.4,
            'date': DateTime(2026, 10, 14, 19, 45, 30),
            'source': 'manual',
            'date_created': now,
          });
          final fields =
              verify(() => userRepository.updateUserFields(uid, captureAny()))
                      .captured
                      .single
                  as List<UserFieldValue>;
          expect(
            {for (final field in fields) field.key: field.value},
            {
              'submitted_weight_kilograms': 82.4,
              'submitted_weight_unit_preference': 'kilograms',
            },
          );
          final events = verify(
            () => analyticsRepository.trackEvent(captureAny()),
          ).captured.cast<LoggableEvent>();
          expect(events.map((e) => e.eventName), [
            'LogWeightView_Save_Start',
            'LogWeightView_Save_Success',
            // blocTest closes the bloc before verifying.
            'LogWeightView_Disappear',
          ]);
        },
      );

      blocTest<LogWeightBloc, LogWeightState>(
        'saves the measurement before the profile',
        build: build,
        seed: ready,
        act: (bloc) => bloc.add(const LogWeightSaveRequested()),
        verify: (_) => verifyInOrder([
          () => bodyRepository.saveMeasurement(any()),
          () => userRepository.updateUserFields(uid, any()),
        ]),
      );

      blocTest<LogWeightBloc, LogWeightState>(
        'in pounds, saves the pounds converted and the pound preference',
        build: build,
        seed: () => ready().copyWith(
          unit: WeightUnitPreference.pounds,
          pounds: 181,
          poundsTenths: 7,
        ),
        act: (bloc) => bloc.add(const LogWeightSaveRequested()),
        verify: (_) {
          const kg = 181.7 / 2.20462;
          final entry =
              verify(() => bodyRepository.saveMeasurement(captureAny()))
                      .captured
                      .single
                  as BodyMeasurementEntry;
          expect(entry.weightKg, kg);
          final fields =
              verify(() => userRepository.updateUserFields(uid, captureAny()))
                      .captured
                      .single
                  as List<UserFieldValue>;
          expect(
            {for (final field in fields) field.key: field.value},
            {
              'submitted_weight_kilograms': kg,
              'submitted_weight_unit_preference': 'pounds',
            },
          );
        },
      );

      blocTest<LogWeightBloc, LogWeightState>(
        'reports a failed save and leaves the profile alone',
        setUp: () =>
            when(() => bodyRepository.saveMeasurement(any()))
                .thenThrow(Exception('denied')),
        build: build,
        seed: ready,
        act: (bloc) => bloc.add(const LogWeightSaveRequested()),
        expect: () => [
          ready().copyWith(status: LogWeightStatus.saving),
          ready().copyWith(status: LogWeightStatus.failure),
        ],
        verify: (_) {
          verifyNever(() => userRepository.updateUserFields(any(), any()));
          final events = verify(
            () => analyticsRepository.trackEvent(captureAny()),
          ).captured.cast<LoggableEvent>();
          final failure = events[1];
          expect(failure.eventName, 'LogWeightView_Save_Fail');
          expect(failure.type, LogType.severe);
          expect(failure.parameters, {
            'error_description': 'Exception: denied',
          });
        },
      );

      blocTest<LogWeightBloc, LogWeightState>(
        'reports a failed profile update',
        setUp: () =>
            when(() => userRepository.updateUserFields(any(), any()))
                .thenThrow(Exception('not-found')),
        build: build,
        seed: ready,
        act: (bloc) => bloc.add(const LogWeightSaveRequested()),
        expect: () => [
          ready().copyWith(status: LogWeightStatus.saving),
          ready().copyWith(status: LogWeightStatus.failure),
        ],
      );

      blocTest<LogWeightBloc, LogWeightState>(
        'can try again after a failure',
        build: build,
        seed: () => ready().copyWith(status: LogWeightStatus.failure),
        act: (bloc) => bloc.add(const LogWeightSaveRequested()),
        expect: () => [
          ready().copyWith(status: LogWeightStatus.saving),
          ready().copyWith(status: LogWeightStatus.saved),
        ],
      );

      for (final status in [
        LogWeightStatus.loading,
        LogWeightStatus.saving,
        LogWeightStatus.saved,
      ]) {
        blocTest<LogWeightBloc, LogWeightState>(
          'does nothing while ${status.name}',
          build: build,
          seed: () => ready().copyWith(status: status),
          act: (bloc) => bloc.add(const LogWeightSaveRequested()),
          expect: () => <LogWeightState>[],
          verify: (_) =>
              verifyNever(() => bodyRepository.saveMeasurement(any())),
        );
      }
    });

    test('events compare by value', () {
      expect(
        const LogWeightWholeChanged(80),
        isNot(const LogWeightWholeChanged(81)),
      );
    });

    test('logs the screen closing', () async {
      await build().close();
      final event =
          verify(() => analyticsRepository.trackEvent(captureAny()))
                  .captured
                  .single
              as LoggableEvent;
      expect(event.eventName, 'LogWeightView_Disappear');
    });
  });

  blocTest<LogWeightBloc, LogWeightState>(
    'gives each weigh-in a new upper-case UUID by default',
    build: () => LogWeightBloc(
      bodyRepository: bodyRepository,
      userRepository: userRepository,
      analyticsRepository: analyticsRepository,
      uid: uid,
    ),
    seed: ready,
    act: (bloc) => bloc.add(const LogWeightSaveRequested()),
    verify: (_) {
      final entry =
          verify(() => bodyRepository.saveMeasurement(captureAny()))
                  .captured
                  .single
              as BodyMeasurementEntry;
      // newDocumentId's own tests check the format.
      expect(entry.id, hasLength(36));
      expect(entry.id, entry.id.toUpperCase());
    },
  );
}
