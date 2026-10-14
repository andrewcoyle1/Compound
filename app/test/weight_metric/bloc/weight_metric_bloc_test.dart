import 'package:app_ui/app_ui.dart' show AppFormat, AppWeightUnit;
import 'package:bloc_test/bloc_test.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const uid = 'uid';
  DateTime now() => DateTime(2026, 10, 15, 9, 30);
  final today = DateTime(2026, 10, 15);

  BodyMeasurementEntry entry(String id, double? weightKg, int daysAgo) {
    final date = DateTime(2026, 10, 15 - daysAgo, 7);
    return BodyMeasurementEntry(
      id: id,
      authorId: uid,
      weightKg: weightKg,
      waistCircumference: weightKg == null ? 81 : null,
      date: date,
      source: WeightSource.manual,
      dateCreated: date,
    );
  }

  final measurements = [
    entry('e1', 73, 2),
    entry('waist', null, 1),
    entry('e2', 72.6, 1),
    entry('e3', 72.4, 0),
  ];
  const pounds = UserModel(
    userId: uid,
    submittedWeightUnitPreference: WeightUnitPreference.pounds,
  );

  late BodyRepository bodyRepository;
  late UserRepository userRepository;

  setUp(() {
    bodyRepository = MockBodyRepository();
    userRepository = MockUserRepository();
    when(() => bodyRepository.watchMeasurements(uid))
        .thenAnswer((_) => Stream.value(measurements));
    when(() => userRepository.watchUser(uid))
        .thenAnswer((_) => Stream.value(null));
  });

  WeightMetricBloc build(WeightMetric metric) => WeightMetricBloc(
    bodyRepository: bodyRepository,
    userRepository: userRepository,
    uid: uid,
    metric: metric,
    now: now,
  );

  group(WeightMetricBloc, () {
    test('opens loading, on a week ending today', () {
      final state = build(WeightMetric.scaleWeight).state;
      expect(state.status, WeightMetricStatus.loading);
      expect(state.range, MetricRange.week);
      expect(state.today, today);
      expect(state.entries, isEmpty);
    });

    blocTest<WeightMetricBloc, WeightMetricState>(
      'reads the weigh-ins in kilograms when the profile has no unit',
      build: () => build(WeightMetric.scaleWeight),
      act: (bloc) => bloc.add(const WeightMetricSubscriptionRequested()),
      verify: (bloc) {
        final state = bloc.state;
        expect(state.status, WeightMetricStatus.loaded);
        expect(state.unit, AppWeightUnit.kilograms);
        expect(state.weighIns!.map((e) => e.id), ['e1', 'e2', 'e3']);
        expect(state.scalePoints.map((p) => p.value), [73.0, 72.6, 72.4]);
        // Scale Weight draws no trend line, and lists the readings.
        expect(state.trendPoints, isEmpty);
        expect(state.entries.map((p) => p.value), [72.4, 72.6, 73.0]);
      },
    );

    blocTest<WeightMetricBloc, WeightMetricState>(
      'plots a trend line alongside the readings, and lists the trend',
      build: () => build(WeightMetric.weightTrend),
      act: (bloc) => bloc.add(const WeightMetricSubscriptionRequested()),
      verify: (bloc) {
        final state = bloc.state;
        expect(state.trendPoints, hasLength(3));
        expect(state.entries, hasLength(3));
        expect(state.entries.first.date, measurements.last.date);
        expect(state.entries.first.value, state.trendKg.last.value);
      },
    );

    blocTest<WeightMetricBloc, WeightMetricState>(
      'one weigh-in gets no trend line',
      setUp: () =>
          when(() => bodyRepository.watchMeasurements(uid))
              .thenAnswer((_) => Stream.value([entry('e1', 73, 0)])),
      build: () => build(WeightMetric.weightTrend),
      act: (bloc) => bloc.add(const WeightMetricSubscriptionRequested()),
      verify: (bloc) {
        expect(bloc.state.trendPoints, isEmpty);
        expect(bloc.state.entries, hasLength(1));
      },
    );

    blocTest<WeightMetricBloc, WeightMetricState>(
      'shows a pounds user every value in pounds',
      setUp: () =>
          when(() => userRepository.watchUser(uid))
              .thenAnswer((_) => Stream.value(pounds)),
      build: () => build(WeightMetric.weightTrend),
      act: (bloc) => bloc.add(const WeightMetricSubscriptionRequested()),
      verify: (bloc) {
        final state = bloc.state;
        expect(state.unit, AppWeightUnit.pounds);
        expect(
          state.scalePoints.last.value,
          72.4 * AppFormat.poundsPerKilogram,
        );
        expect(
          state.trendPoints.last.value,
          state.trendKg.last.value * AppFormat.poundsPerKilogram,
        );
      },
    );

    blocTest<WeightMetricBloc, WeightMetricState>(
      'falls back to kilograms when the profile cannot be read',
      setUp: () =>
          when(() => userRepository.watchUser(uid))
              .thenAnswer((_) => Stream.error(Exception('denied'))),
      build: () => build(WeightMetric.scaleWeight),
      act: (bloc) => bloc.add(const WeightMetricSubscriptionRequested()),
      verify: (bloc) {
        expect(bloc.state.status, WeightMetricStatus.loaded);
        expect(bloc.state.unit, AppWeightUnit.kilograms);
      },
    );

    blocTest<WeightMetricBloc, WeightMetricState>(
      'fails when the weigh-ins cannot be read',
      setUp: () =>
          when(() => bodyRepository.watchMeasurements(uid))
              .thenAnswer((_) => Stream.error(Exception('offline'))),
      build: () => build(WeightMetric.scaleWeight),
      act: (bloc) => bloc.add(const WeightMetricSubscriptionRequested()),
      verify: (bloc) => expect(bloc.state.status, WeightMetricStatus.failure),
    );

    blocTest<WeightMetricBloc, WeightMetricState>(
      'picks up a weigh-in logged while the screen is open',
      setUp: () => when(() => bodyRepository.watchMeasurements(uid)).thenAnswer(
        (_) => Stream.fromIterable([
          [entry('e1', 73, 1)],
          [entry('e1', 73, 1), entry('e2', 72.6, 0)],
        ]),
      ),
      build: () => build(WeightMetric.weightTrend),
      act: (bloc) => bloc.add(const WeightMetricSubscriptionRequested()),
      verify: (bloc) => expect(bloc.state.entries, hasLength(2)),
    );

    blocTest<WeightMetricBloc, WeightMetricState>(
      'changes the range',
      build: () => build(WeightMetric.scaleWeight),
      act: (bloc) =>
          bloc.add(const WeightMetricRangeSelected(MetricRange.year)),
      expect: () => [
        WeightMetricState(
          metric: WeightMetric.scaleWeight,
          today: today,
          range: MetricRange.year,
        ),
      ],
    );
  });
}
