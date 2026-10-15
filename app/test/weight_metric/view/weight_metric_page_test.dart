import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/weight_metric/weight_metric.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const uid = 'uid';
  DateTime now() => DateTime(2026, 10, 15, 9, 30);
  final samples = sampleBodyMeasurements(uid: uid, now: now());

  late AppBloc appBloc;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)),
    );
  });

  /// The view over a real bloc, opened at [now].
  Future<WeightMetricBloc> pumpView(
    WidgetTester tester,
    WeightMetric metric, {
    BodyRepository? bodyRepository,
    List<BodyMeasurementEntry>? measurements,
    bool allData = false,
  }) async {
    final bloc = WeightMetricBloc(
      bodyRepository:
          bodyRepository ??
          InMemoryBodyRepository(measurements: measurements ?? samples),
      userRepository: InMemoryUserRepository(),
      uid: uid,
      metric: metric,
      now: now,
    )..add(const WeightMetricSubscriptionRequested());
    await tester.pumpApp(
      BlocProvider.value(
        value: bloc,
        child: WeightMetricView(allData: allData),
      ),
    );
    await tester.pump();
    return bloc;
  }

  group(WeightMetricPage, () {
    testWidgets('builds its bloc from the signed-in user', (tester) async {
      await tester.pumpApp(
        const WeightMetricPage(metric: WeightMetric.scaleWeight),
        appBloc: appBloc,
        bodyRepository: InMemoryBodyRepository(measurements: samples),
        userRepository: InMemoryUserRepository(),
      );
      await tester.pump();
      expect(find.byType(WeightMetricView), findsOneWidget);
      expect(find.byType(MetricDetailView), findsOneWidget);
    });

    testWidgets('shows nothing when signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(
        const WeightMetricPage(metric: WeightMetric.scaleWeight),
        appBloc: appBloc,
      );
      expect(find.byType(WeightMetricView), findsNothing);
    });
  });

  group(WeightMetricView, () {
    testWidgets('shows a spinner while the weigh-ins load', (tester) async {
      final repository = MockBodyRepository();
      when(() => repository.watchMeasurements(uid))
          .thenAnswer((_) => const Stream.empty());
      await pumpView(
        tester,
        WeightMetric.scaleWeight,
        bodyRepository: repository,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the chart, its readings and the way to all data', (
      tester,
    ) async {
      await pumpView(tester, WeightMetric.scaleWeight);
      expect(find.text('Scale Weight'), findsWidgets);
      expect(find.byType(MetricChart), findsOneWidget);
      expect(find.text('Latest: Today'), findsOneWidget);
      expect(find.text('Average'), findsOneWidget);
      expect(find.byType(MethodInfoButton), findsNothing);
      // The chart reads as one summary.
      expect(
        find.bySemanticsLabel(RegExp('^Scale Weight chart, .+ average .+ kg')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('Show All Data'), 100);
      expect(find.text('Show All Data'), findsOneWidget);
    });

    testWidgets('offers Log Weight', (tester) async {
      await pumpView(tester, WeightMetric.scaleWeight);
      expect(find.byTooltip('Log Weight'), findsOneWidget);
    });

    testWidgets('All Recorded Data has no Log Weight', (tester) async {
      await pumpView(tester, WeightMetric.scaleWeight, allData: true);
      expect(find.byTooltip('Log Weight'), findsNothing);
    });

    testWidgets('changes the range from the picker', (tester) async {
      final bloc = await pumpView(tester, WeightMetric.scaleWeight);
      await tester.tap(find.text('Y'));
      await tester.pump();
      expect(bloc.state.range, MetricRange.year);
    });

    testWidgets('Weight Trend draws the trend and explains its method', (
      tester,
    ) async {
      await pumpView(tester, WeightMetric.weightTrend);
      expect(find.text('Trend Weight'), findsOneWidget);
      await tester.tap(find.byType(MethodInfoButton));
      await tester.pumpAndSettle();
      expect(find.byType(MethodInfoSheet), findsOneWidget);
    });

    testWidgets('says when there are no weigh-ins', (tester) async {
      await pumpView(tester, WeightMetric.weightTrend, measurements: const []);
      expect(find.text('No weight entries'), findsOneWidget);
      expect(find.byType(MetricDetailView), findsNothing);
    });

    testWidgets('says when the weigh-ins cannot be read', (tester) async {
      final repository = MockBodyRepository();
      when(() => repository.watchMeasurements(uid))
          .thenAnswer((_) => Stream.error(Exception('offline')));
      await pumpView(
        tester,
        WeightMetric.scaleWeight,
        bodyRepository: repository,
      );
      expect(find.text("Your weigh-ins couldn't be loaded."), findsOneWidget);
    });

    testWidgets('lists every entry, newest first, as All Recorded Data', (
      tester,
    ) async {
      await pumpView(
        tester,
        WeightMetric.scaleWeight,
        measurements: [
          for (final (i, kg) in [73.0, 72.5].indexed)
            BodyMeasurementEntry(
              id: 'e$i',
              authorId: uid,
              weightKg: kg,
              date: DateTime(2026, 10, 14 + i, 7),
              source: WeightSource.manual,
              dateCreated: DateTime(2026, 10, 14 + i, 7),
            ),
        ],
        allData: true,
      );
      expect(find.text('All Recorded Data'), findsOneWidget);
      expect(find.byType(MetricAllDataView), findsOneWidget);
      final newest = tester.getTopLeft(find.text('72.5 kg'));
      final oldest = tester.getTopLeft(find.text('73 kg'));
      expect(newest.dy, lessThan(oldest.dy));
      expect(find.text('Oct 15, 2026'), findsOneWidget);
    });
  });
}
