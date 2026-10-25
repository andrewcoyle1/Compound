import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition_overview/logic/nutrition_overview.dart';
import 'package:compound/nutrition_overview/nutrition_overview.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound_charts/compound_charts.dart';
import 'package:compound_maths/compound_maths.dart' show checkInWeekStart;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../helpers/helpers.dart';

class _MockGoRouter extends Mock implements GoRouter;

void main() {
  const uid = StagingData.uid;

  late AppBloc appBloc;
  late GoRouter router;
  late StagingData data;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)),
    );
    router = _MockGoRouter();
    when(
      () => router.pushNamed<Object?>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer((_) async => null);
    data = StagingData();
  });

  Future<void> pumpPage(WidgetTester tester, {String? dayKey}) async {
    await tester.pumpApp(
      InheritedGoRouter(
        goRouter: router,
        child: NutritionOverviewPage(
          dayKey: dayKey ?? localDayKey(data.now),
          now: () => data.now,
        ),
      ),
      appBloc: appBloc,
      userRepository: data.users,
      nutritionRepository: data.nutrition,
      bodyRepository: data.body,
      programRepository: data.programs,
      checkInRepository: data.checkIns,
    );
    await tester.pump();
  }

  group(NutritionOverviewPage, () {
    // The page reads the staging data at the data's own moment, whatever
    // the clock says. The check-in's week turns on Monday, so cover a
    // Monday, a Sunday and mid-week, each at 1pm so the day has meals.
    for (final moment in [
      DateTime(2026, 10, 19, 13),
      DateTime(2026, 10, 18, 13),
      stagingNow,
    ]) {
      group('on ${localDayKey(moment)}', () {
        setUp(() => data = StagingData(now: moment));
        final week = checkInWeekStart(localDayKey(moment));

        testWidgets('shows the check-in card, the day and its nutrients', (
          tester,
        ) async {
          await pumpPage(tester);
          expect(find.text('Nutrition Overview'), findsOneWidget);
          expect(find.text('WEEKLY CHECK-IN READY'), findsOneWidget);
          expect(find.text('NEW TARGETS SUGGESTED'), findsNothing);
          expect(find.text('CALORIES'), findsOneWidget);
          expect(find.textContaining(RegExp('^OF .*KCAL')), findsOneWidget);
          // The macros' method, at the hero's header.
          expect(find.byType(MethodInfoButton), findsOneWidget);
          // Calories as a share of the day's target, and a ring per macro.
          final bar = tester.widget<BulletBar>(find.byType(BulletBar));
          expect(bar.value, inInclusiveRange(0, 1));
          expect(find.byType(ProgressArc), findsNWidgets(3));
          expect(find.text('PROTEIN'), findsOneWidget);

          // The check-in card starts it, as Today's does.
          await tester.tap(find.text('WEEKLY CHECK-IN READY'));
          verify(
            () => router.pushNamed<Object?>(
              'checkIn',
              queryParameters: {'week': week},
            ),
          ).called(1);

          expect(find.text('Top Contributors'), findsOneWidget);
          // A food's macros, as each contributor's row gives them.
          final contributor = find.textContaining('P · ');
          expect(contributor, findsNothing);
          await tester.ensureVisible(find.text('Contributors'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Contributors'));
          await tester.pump();
          expect(contributor, findsWidgets);

          await tester.scrollUntilVisible(find.text('Fiber'), 300);
          expect(find.text('Carb Breakdown'), findsOneWidget);
        });

        testWidgets('offers the proposal once the check-in is skipped', (
          tester,
        ) async {
          await pumpPage(tester);
          await tester.tap(find.text('Skip This Week'));
          await tester.pump();
          expect(find.text('WEEKLY CHECK-IN READY'), findsNothing);
          expect(find.text('NEW TARGETS SUGGESTED'), findsOneWidget);
          expect(find.textContaining('kcal a day, down from'), findsOneWidget);
          // The card's info button joins the macros'.
          expect(find.byType(MethodInfoButton), findsNWidgets(2));
          await tester.tap(find.text('Not now'));
          await tester.pump();
          expect(find.text('NEW TARGETS SUGGESTED'), findsNothing);
        });

        testWidgets('alerts when the plan does not save', (tester) async {
          data = StagingData(
            now: moment,
            records: [
              CheckInRecord(
                authorId: uid,
                lastCompletedWeekStart: localMidnight(week),
              ),
            ],
          );
          final nutrition = _RefusingNutrition(data.nutrition);
          await tester.pumpApp(
            InheritedGoRouter(
              goRouter: router,
              child: NutritionOverviewPage(
                dayKey: localDayKey(data.now),
                now: () => data.now,
              ),
            ),
            appBloc: appBloc,
            userRepository: data.users,
            nutritionRepository: nutrition,
            bodyRepository: data.body,
            programRepository: data.programs,
            checkInRepository: data.checkIns,
          );
          await tester.pump();
          await tester.tap(find.text('Accept'));
          await tester.pump();
          await tester.pump();
          expect(find.text('Unable to Update Your Targets'), findsOneWidget);
        });
      });
    }

    testWidgets('a day with nothing logged leaves out the nutrients', (
      tester,
    ) async {
      await pumpPage(tester, dayKey: '2026-01-01');
      expect(find.text('Carb Breakdown'), findsNothing);
      // Nothing eaten: every ring empty.
      for (final ring in tester.widgetList<ProgressArc>(
        find.byType(ProgressArc),
      )) {
        expect(ring.value, 0);
      }
    });

    testWidgets('says when the day cannot be read', (tester) async {
      await tester.pumpApp(
        NutritionOverviewPage(dayKey: localDayKey(data.now)),
        appBloc: appBloc,
        userRepository: data.users,
        nutritionRepository: _ThrowingNutrition(),
        bodyRepository: data.body,
        checkInRepository: data.checkIns,
      );
      await tester.pump();
      expect(find.text("Your meals couldn't be loaded."), findsOneWidget);
    });

    testWidgets('is empty when signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(
        const NutritionOverviewPage(dayKey: '2026-10-15'),
        appBloc: appBloc,
      );
      expect(find.byType(NutritionOverviewView), findsNothing);
    });

    test('names every section and nutrient', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect({
        for (final s in NutrientSection.values) sectionTitle(l10n, s),
      }, hasLength(NutrientSection.values.length));
      expect({
        for (final line in NutrientLine.values) nutrientName(l10n, line),
      }, hasLength(NutrientLine.values.length));
    });
  });
}

class _RefusingNutrition extends InMemoryNutritionRepository {
  new(this._inner);

  final InMemoryNutritionRepository _inner;

  @override
  Stream<List<MealLogModel>> watchMeals(
    String uid, {
    bool includeHiddenHealthImports = false,
  }) => _inner.watchMeals(uid);

  @override
  Stream<DietPlan?> watchDietPlan(String uid) => _inner.watchDietPlan(uid);

  @override
  Future<void> saveDietPlan(DietPlan plan) =>
      Future.error(Exception('refused'));
}

class _ThrowingNutrition extends InMemoryNutritionRepository {
  @override
  Stream<List<MealLogModel>> watchMeals(
    String uid, {
    bool includeHiddenHealthImports = false,
  }) => Stream.error(Exception('offline'));
}
