import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

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
    when(() => router.canPop()).thenReturn(true);
    when(() => router.pop<Object?>()).thenReturn(null);
    when(() => router.go(any())).thenReturn(null);
    data = StagingData();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpApp(
      InheritedGoRouter(
        goRouter: router,
        child: CheckInPage(weekStart: DateTime(2026, 10, 12)),
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

  Future<void> tapCta(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(AppCtaButton, label));
    await tester.pump();
    await tester.pump();
  }

  group(CheckInPage, () {
    testWidgets('walks the week to new targets', (tester) async {
      await pumpPage(tester);
      expect(find.text('Your Week'), findsOneWidget);
      expect(find.text('The last seven days'), findsOneWidget);
      expect(find.text('7 of 7'), findsOneWidget);
      expect(find.byType(MethodInfoButton), findsOneWidget);

      await tapCta(tester, 'Continue');
      expect(find.text('Partial Logging'), findsOneWidget);
      expect(find.text('Any days you did not finish logging?'), findsOneWidget);
      expect(find.byType(AppListRowToggle), findsNWidgets(7));
      await tester.tap(find.byType(Switch).first);
      await tester.pump();

      await tapCta(tester, 'Continue');
      expect(find.text('Logging Break'), findsOneWidget);
      expect(find.text('Take a break from logging?'), findsOneWidget);
      expect(find.text('Start a Break'), findsOneWidget);

      await tapCta(tester, 'No Thanks');
      expect(find.text('Program Update'), findsOneWidget);
      expect(find.text('New targets suggested'), findsOneWidget);
      expect(find.textContaining('kcal a day, down from'), findsOneWidget);

      await tapCta(tester, 'Accept');
      verify(() => router.pop<Object?>()).called(1);
    });

    testWidgets('closes when dismissed', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.byType(CloseButton));
      await tester.pump();
      verify(() => router.pop<Object?>()).called(1);
    });

    testWidgets('closes to Today when opened directly', (tester) async {
      when(() => router.canPop()).thenReturn(false);
      await pumpPage(tester);
      await tester.tap(find.byType(CloseButton));
      await tester.pump();
      verify(() => router.go('/today')).called(1);
    });

    testWidgets('shows the targets unchanged, and an open break', (
      tester,
    ) async {
      data = StagingData(
        withPlan: false,
        loggingBreaks: [
          LoggingBreak(authorId: uid, startDate: DateTime(2026, 10, 14)),
        ],
        measurements: const [],
      );
      await pumpPage(tester);
      expect(find.text('Your Week'), findsOneWidget);
      await tapCta(tester, 'Continue');
      await tapCta(tester, 'Continue');
      expect(find.text('Weigh-In'), findsOneWidget);
      expect(find.byType(WeightWheels), findsOneWidget);
      await tapCta(tester, 'Skip');
      expect(find.text('You are on a logging break'), findsOneWidget);
      expect(find.text('End My Break'), findsOneWidget);
      await tapCta(tester, 'Stay on a Break');
      expect(find.text('Your targets are unchanged this week'), findsOneWidget);
      expect(find.text('Expenditure'), findsOneWidget);
      expect(find.text('Weight trend'), findsOneWidget);
      await tapCta(tester, 'Done');
      verify(() => router.pop<Object?>()).called(1);
    });

    testWidgets('says when a save fails', (tester) async {
      data = StagingData(checkIns: _RefusingCheckIns(StagingData().checkIns));
      await pumpPage(tester);
      await tapCta(tester, 'Continue');
      await tapCta(tester, 'Continue');
      expect(find.text('Unable to Save Your Answer'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Partial Logging'), findsOneWidget);
    });

    test('names every step', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        [for (final step in CheckInStep.values) stepTitle(l10n, step)],
        [
          'Your Week',
          'Partial Logging',
          'Weigh-In',
          'Fasting',
          'Logging Break',
          'Program Update',
        ],
      );
    });

    testWidgets('is empty when signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(
        CheckInPage(weekStart: DateTime(2026, 10, 12)),
        appBloc: appBloc,
      );
      expect(find.byType(CheckInView), findsNothing);
    });
  });
}

/// Reads through, and refuses every write.
class _RefusingCheckIns implements CheckInRepository {
  new(this._inner);

  final CheckInRepository _inner;

  @override
  Stream<NutritionStrategySettings> watchStrategySettings(String uid) =>
      _inner.watchStrategySettings(uid);

  @override
  Stream<List<NutritionDayAnnotation>> watchDayAnnotations(String uid) =>
      _inner.watchDayAnnotations(uid);

  @override
  Stream<LoggingBreak?> watchLoggingBreak(String uid) =>
      _inner.watchLoggingBreak(uid);

  @override
  Stream<CheckInRecord?> watchCheckInRecord(String uid) =>
      _inner.watchCheckInRecord(uid);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<void>.error(Exception('refused'));
}
