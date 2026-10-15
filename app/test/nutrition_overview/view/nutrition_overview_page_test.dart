import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition_overview/logic/nutrition_overview.dart';
import 'package:compound/nutrition_overview/nutrition_overview.dart';
import 'package:compound/science/view/method_info_button.dart';
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
        child: NutritionOverviewPage(dayKey: dayKey ?? localDayKey(data.now)),
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
    testWidgets('shows the check-in card, the day and its nutrients', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text('Nutrition Overview'), findsOneWidget);
      expect(find.text('Weekly check-in ready'), findsOneWidget);
      expect(find.text('New targets suggested'), findsNothing);
      expect(find.textContaining('consumed'), findsOneWidget);
      expect(find.text('Macros'), findsOneWidget);
      expect(find.byType(MethodInfoButton), findsOneWidget);

      await tester.tap(find.text('Start'));
      verify(
        () => router.pushNamed<Object?>(
          'checkIn',
          queryParameters: {'week': '2026-10-12'},
        ),
      ).called(1);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(find.text('Top Contributors'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Fiber'), 300);
      expect(find.text('Carb Breakdown'), findsOneWidget);
    });

    testWidgets('offers the proposal once the check-in is skipped', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.tap(find.text('Skip This Week'));
      await tester.pump();
      expect(find.text('Weekly check-in ready'), findsNothing);
      expect(find.text('New targets suggested'), findsOneWidget);
      expect(find.textContaining('kcal a day, down from'), findsOneWidget);
      // The card's info button joins the macros'.
      expect(find.byType(MethodInfoButton), findsNWidgets(2));
      await tester.tap(find.text('Not now'));
      await tester.pump();
      expect(find.text('New targets suggested'), findsNothing);
    });

    testWidgets('alerts when the plan does not save', (tester) async {
      data = StagingData(
        records: [
          CheckInRecord(
            authorId: uid,
            lastCompletedWeekStart: DateTime(2026, 10, 12),
          ),
        ],
      );
      final nutrition = _RefusingNutrition(data.nutrition);
      await tester.pumpApp(
        InheritedGoRouter(
          goRouter: router,
          child: NutritionOverviewPage(dayKey: localDayKey(data.now)),
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

    testWidgets('a day with nothing logged leaves out the nutrients', (
      tester,
    ) async {
      await pumpPage(tester, dayKey: '2026-01-01');
      expect(find.text('Carb Breakdown'), findsNothing);
      expect(find.text('—'), findsNWidgets(3));
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
