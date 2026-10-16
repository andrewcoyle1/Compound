import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/expenditure_metric/expenditure_metric.dart';
import 'package:compound/metric_detail/metric_detail.dart';
import 'package:compound_maths/compound_maths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../helpers/helpers.dart';

class _MockGoRouter extends Mock implements GoRouter;

ExpenditureEstimate _estimate(String day, double kcal) => ExpenditureEstimate(
  day: day,
  kcal: kcal,
  source: ExpenditureSource.adaptive,
  isProvisional: false,
  trendWeightKg: 80,
  weeklyTrendChangeKg: -0.4,
  loggedDays: 26,
  weighInCount: 24,
  windowDays: 28,
  stepAdjustmentKcal: 0,
  sdKcal: 110,
  weeklyTrendChangeSDKg: null,
  recentIntakeKcal: null,
);

void main() {
  const uid = StagingData.uid;

  group('expenditurePoints', () {
    test('is the last 90 estimates', () {
      final history = [
        for (var i = 0; i < 100; i++)
          _estimate(addDays('2026-07-08', i), 2000.0 + i),
      ];
      final points = expenditurePoints(history, 1800, '2026-10-15');
      expect(points, hasLength(90));
      expect(points.first.value, 2010);
      expect(points.last.date, DateTime(2026, 10, 15));
    });

    test('is 90 flat days of the formula with no history', () {
      final points = expenditurePoints(const [], 1800, '2026-10-15');
      expect(points, hasLength(90));
      expect(points.every((p) => p.value == 1800), isTrue);
      expect(points.first.date, DateTime(2026, 7, 18));
    });
  });

  test('energyBalance keeps only the days with calories logged', () {
    final balance = energyBalance(
      history: [_estimate('2026-10-14', 2400)],
      formulaKcal: 2000,
      meals: [
        MealLogModel(
          mealId: 'm',
          authorId: uid,
          dayKey: '2026-10-14',
          date: DateTime(2026, 10, 14, 12),
          items: [
            const MealItemModel(
              itemId: 'i',
              sourceType: MealItemSourceType.quickAdd,
              sourceId: 'quick_add',
              displayName: 'Lunch',
              amount: 1,
              unit: 'serving',
              nutrients: NutrientMap({NutrientKey.calories: 900}),
            ),
          ],
        ),
      ],
      today: '2026-10-15',
    );
    expect(balance.expenditure, hasLength(90));
    expect(balance.expenditure.first.value, 2000);
    expect(balance.expenditure.last.value, 2400);
    expect(balance.days, [
      (date: DateTime(2026, 10, 14), expenditure: 2400.0, intake: 900.0),
    ]);
  });

  group(ExpenditureMetricPage, () {
    late AppBloc appBloc;
    late GoRouter router;
    late StagingData data;
    late AnalyticsRecorder analytics;

    setUp(() {
      appBloc = MockAppBloc();
      when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
      when(() => appBloc.state).thenReturn(
        const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)),
      );
      router = _MockGoRouter();
      when(() => router.goNamed(any())).thenReturn(null);
      when(() => router.pushNamed<Object?>(any()))
          .thenAnswer((_) async => null);
      data = StagingData();
      analytics = AnalyticsRecorder();
    });

    Future<void> pumpPage(
      WidgetTester tester,
      ExpenditureMetric metric, {
      bool allData = false,
      NutritionRepository? nutrition,
    }) async {
      await tester.pumpApp(
        InheritedGoRouter(
          goRouter: router,
          child: ExpenditureMetricPage(metric: metric, allData: allData),
        ),
        appBloc: appBloc,
        userRepository: data.users,
        nutritionRepository: nutrition ?? data.nutrition,
        bodyRepository: data.body,
        checkInRepository: data.checkIns,
        analyticsRepository: analytics,
      );
      await tester.pump();
    }

    testWidgets('Expenditure charts the estimate with today summarised', (
      tester,
    ) async {
      await pumpPage(tester, ExpenditureMetric.expenditure);
      expect(find.text('Expenditure'), findsWidgets);
      expect(find.byType(MetricDetailView), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(ExpenditureEstimateSummary),
        300,
      );
      expect(find.text('Today'), findsWidgets);
      expect(find.textContaining('based on what you logged'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Show All Data'), 300);
      await tester.tap(find.text('Show All Data'));
      verify(() => router.goNamed('expenditureData')).called(1);
      expect(analytics.names.first, 'ExpenditureDetailView_Appear');
      await tester.tap(find.byTooltip('Edit Profile'));
      verify(() => router.pushNamed<Object?>('editProfile')).called(1);
    });

    testWidgets('Energy Balance charts intake against expenditure', (
      tester,
    ) async {
      await pumpPage(tester, ExpenditureMetric.energyBalance);
      expect(find.text('Energy Balance'), findsOneWidget);
      expect(find.text('Intake'), findsOneWidget);
      // Swift's combo chart: intake as bars that average, under the
      // expenditure line.
      final series = tester
          .widget<MetricDetailView>(find.byType(MetricDetailView))
          .series;
      expect([for (final s in series) s.label], ['Intake', 'Expenditure']);
      expect(series.first.isBar, isTrue);
      expect(series.first.isTotal, isFalse);
      expect(series.last.isLine, isTrue);
      expect(find.byType(ExpenditureEstimateSummary), findsNothing);
      expect(find.byTooltip('Log Meal'), findsOneWidget);
      expect(analytics.names.first, 'EnergyBalanceView_Appear');
    });

    testWidgets('lists every day as a deficit or surplus', (tester) async {
      await pumpPage(tester, ExpenditureMetric.energyBalance, allData: true);
      expect(find.text('All Recorded Data'), findsOneWidget);
      expect(find.textContaining('deficit'), findsWidgets);
    });

    testWidgets('lists every day of expenditure', (tester) async {
      await pumpPage(tester, ExpenditureMetric.expenditure, allData: true);
      expect(find.textContaining('kcal'), findsWidgets);
    });

    testWidgets('Energy Balance with nothing logged offers a meal', (
      tester,
    ) async {
      await pumpPage(
        tester,
        ExpenditureMetric.energyBalance,
        nutrition: InMemoryNutritionRepository(),
      );
      expect(find.text('No data for the last 90 days'), findsOneWidget);
      expect(find.text('Log Meal'), findsOneWidget);
    });

    testWidgets('says when the logs cannot be read', (tester) async {
      await pumpPage(
        tester,
        ExpenditureMetric.energyBalance,
        nutrition: _ThrowingNutrition(),
      );
      expect(find.text("Your meals couldn't be loaded."), findsOneWidget);
      expect(analytics.names, contains('EnergyBalanceView_Load_Fail'));
    });

    testWidgets('an Expenditure failure is not logged', (tester) async {
      await pumpPage(
        tester,
        ExpenditureMetric.expenditure,
        nutrition: _ThrowingNutrition(),
      );
      expect(analytics.names, isNot(contains('EnergyBalanceView_Load_Fail')));
    });

    testWidgets('changes range and logs leaving', (tester) async {
      await pumpPage(tester, ExpenditureMetric.expenditure);
      await tester.tap(find.text('W'));
      await tester.pump();
      final segmented = tester.widget<SegmentedButton<MetricRange>>(
        find.byType(SegmentedButton<MetricRange>),
      );
      expect(segmented.selected, {MetricRange.week});
      await tester.pumpWidget(const SizedBox());
      expect(analytics.names.last, 'ExpenditureDetailView_Disappear');
    });

    testWidgets('is empty when signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(
        const ExpenditureMetricPage(metric: ExpenditureMetric.expenditure),
        appBloc: appBloc,
      );
      expect(find.byType(ExpenditureMetricView), findsNothing);
    });
  });

  group(ExpenditureEstimateSummary, () {
    ExpenditureEstimate estimate(ExpenditureSource source, double? sd) =>
        ExpenditureEstimate(
          day: '2026-10-15',
          kcal: 2450,
          source: source,
          isProvisional: source != ExpenditureSource.adaptive,
          trendWeightKg: 80,
          weeklyTrendChangeKg: null,
          loggedDays: 0,
          weighInCount: 0,
          windowDays: 0,
          stepAdjustmentKcal: 0,
          sdKcal: sd,
          weeklyTrendChangeSDKg: null,
          recentIntakeKcal: null,
        );

    for (final (source, sd, badge, detail) in [
      (
        ExpenditureSource.adaptive,
        100.0,
        'High confidence',
        'based on what you logged',
      ),
      (ExpenditureSource.adaptive, 200.0, 'Medium confidence', 'Likely'),
      (ExpenditureSource.adaptive, 300.0, 'Low confidence', 'Likely'),
      (ExpenditureSource.fixed, null, 'Calibrating', 'Fixed at your'),
      (ExpenditureSource.prior, null, 'Calibrating', '21 days and 14'),
    ]) {
      testWidgets('$badge for $source', (tester) async {
        await tester.pumpApp(
          ExpenditureEstimateSummary(estimate: estimate(source, sd)),
        );
        expect(find.text(badge), findsOneWidget);
        expect(find.textContaining(detail), findsOneWidget);
      });
    }
  });

  test('every metric has a title and a data route', () {
    for (final metric in ExpenditureMetric.values) {
      expect(metric.dataRouteName, '${metric.name}Data');
    }
  });
}

class _ThrowingNutrition extends InMemoryNutritionRepository {
  @override
  Stream<List<MealLogModel>> watchMeals(
    String uid, {
    bool includeHiddenHealthImports = false,
  }) => Stream.error(Exception('offline'));
}
