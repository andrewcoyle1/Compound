import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/log_weight/log_weight.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPicker;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

class _MockLogWeightBloc extends MockBloc<LogWeightEvent, LogWeightState>
    implements LogWeightBloc;

class _MockGoRouter extends Mock implements GoRouter;

void main() {
  const uid = 'me';
  final now = DateTime(2026, 10, 15, 19, 45);

  late AppBloc appBloc;
  late LogWeightBloc bloc;
  late GoRouter router;
  late List<AppHaptic> haptics;

  LogWeightState ready() =>
      LogWeightState(date: now, status: LogWeightStatus.ready);

  setUpAll(() => registerFallbackValue(const LogWeightStarted()));

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)),
    );
    bloc = _MockLogWeightBloc();
    when(() => bloc.state).thenReturn(ready());
    router = _MockGoRouter();
    when(() => router.canPop()).thenReturn(true);
    when(() => router.pop<Object?>()).thenReturn(null);
    when(() => router.go(any())).thenReturn(null);
    haptics = [];
  });

  Future<void> pumpView(WidgetTester tester, {double textScale = 1}) async {
    AppHaptics.debugPlay = haptics.add;
    addTearDown(() => AppHaptics.debugPlay = null);
    await tester.pumpApp(
      InheritedGoRouter(
        goRouter: router,
        child: BlocProvider.value(value: bloc, child: const LogWeightView()),
      ),
      textScale: textScale,
    );
  }

  group(LogWeightPage, () {
    testWidgets('opens on the latest weigh-in for the signed-in user', (
      tester,
    ) async {
      await tester.pumpApp(
        const LogWeightPage(),
        appBloc: appBloc,
        bodyRepository: InMemoryBodyRepository(
          measurements: [
            BodyMeasurementEntry(
              id: 'w',
              authorId: uid,
              weightKg: 82.4,
              date: now,
              source: WeightSource.manual,
              dateCreated: now,
            ),
          ],
        ),
        userRepository: InMemoryUserRepository(),
      );
      await tester.pump();
      expect(find.byType(LogWeightView), findsOneWidget);
      expect(find.text('82.4'), findsOneWidget);
    });

    testWidgets('shows nothing when signed out', (tester) async {
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(const LogWeightPage(), appBloc: appBloc);
      expect(find.byType(LogWeightView), findsNothing);
    });
  });

  group(LogWeightView, () {
    testWidgets('shows a spinner and no save while loading', (tester) async {
      when(() => bloc.state).thenReturn(LogWeightState(date: now));
      await pumpView(tester);
      expect(find.byType(CupertinoPicker), findsNothing);
      final save = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, AppSymbols.selected),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('shows the day and the weight in kilograms', (tester) async {
      when(() => bloc.state)
          .thenReturn(ready().copyWith(kilograms: 82, kilogramsTenths: 4));
      await pumpView(tester);
      expect(find.text('Log Weight'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Oct 15, 2026'), findsOneWidget);
      expect(find.text('Weight'), findsOneWidget);
      expect(find.text('82.4'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
    });

    testWidgets('writes the date in the device region', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('en', 'GB');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      when(() => bloc.state).thenReturn(ready());
      await pumpView(tester);
      expect(find.text('15 Oct 2026'), findsOneWidget);
    });

    testWidgets('shows the weight in pounds', (tester) async {
      when(() => bloc.state).thenReturn(
        ready().copyWith(
          unit: WeightUnitPreference.pounds,
          pounds: 181,
          poundsTenths: 7,
        ),
      );
      await pumpView(tester);
      expect(find.text('181.7'), findsOneWidget);
      expect(find.text('lb'), findsOneWidget);
    });

    testWidgets('sends what the user changes', (tester) async {
      await pumpView(tester);

      await tester.enterText(find.byType(TextField), '71.2');
      await tester.pump();
      verify(() => bloc.add(const LogWeightWholeChanged(71))).called(1);
      verify(() => bloc.add(const LogWeightTenthsChanged(2))).called(1);

      await tester.tap(find.text('kg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('lb').last);
      await tester.pumpAndSettle();
      verify(
        () => bloc.add(const LogWeightUnitChanged(WeightUnitPreference.pounds)),
      ).called(1);

      await tester.tap(find.byTooltip('Save'));
      verify(() => bloc.add(const LogWeightSaveRequested())).called(1);
    });

    testWidgets('keeps a weight outside the span from being saved', (
      tester,
    ) async {
      await pumpView(tester);
      for (final text in ['25', '']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump();
        final save = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, AppSymbols.selected),
        );
        expect(save.onPressed, isNull);
      }
      verifyNever(() => bloc.add(any(that: isA<LogWeightWholeChanged>())));
    });

    testWidgets('picks the day from a calendar up to today', (tester) async {
      await pumpView(tester);
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('14'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      verify(() => bloc.add(LogWeightDateChanged(DateTime(2026, 10, 14))))
          .called(1);
    });

    testWidgets('keeps the day when the calendar is cancelled', (tester) async {
      await pumpView(tester);
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      verifyNever(() => bloc.add(any(that: isA<LogWeightDateChanged>())));
    });

    testWidgets('shows a spinner in place of save while saving', (
      tester,
    ) async {
      when(() => bloc.state)
          .thenReturn(ready().copyWith(status: LogWeightStatus.saving));
      await pumpView(tester);
      // The confirm button keeps its place, spinning and disabled.
      expect(find.byType(AppSpinner), findsOneWidget);
      final save = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Save'),
          matching: find.byType(IconButton),
        ),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('on save, plays the success haptic and closes', (tester) async {
      whenListen(
        bloc,
        Stream.fromIterable([
          ready().copyWith(status: LogWeightStatus.saving),
          ready().copyWith(status: LogWeightStatus.saved),
        ]),
        initialState: ready(),
      );
      await pumpView(tester);
      await tester.pump();
      expect(haptics, [AppHaptic.success]);
      verify(() => router.pop<Object?>()).called(1);
    });

    testWidgets('on save, goes to Today when there is nothing to go back to', (
      tester,
    ) async {
      when(() => router.canPop()).thenReturn(false);
      whenListen(
        bloc,
        Stream.value(ready().copyWith(status: LogWeightStatus.saved)),
        initialState: ready(),
      );
      await pumpView(tester);
      await tester.pump();
      verify(() => router.go(AppTab.today.path)).called(1);
    });

    testWidgets('closes without saving', (tester) async {
      await pumpView(tester);
      await tester.tap(find.byTooltip('Close'));
      verify(() => router.pop<Object?>()).called(1);
      verifyNever(() => bloc.add(const LogWeightSaveRequested()));
    });

    testWidgets('on failure, plays the error haptic and says so', (
      tester,
    ) async {
      whenListen(
        bloc,
        Stream.value(ready().copyWith(status: LogWeightStatus.failure)),
        initialState: ready(),
      );
      await pumpView(tester);
      await tester.pumpAndSettle();
      expect(haptics, [AppHaptic.error]);
      expect(find.text('Unable to Save Weight'), findsOneWidget);
      verifyNever(() => router.pop<Object?>());

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Unable to Save Weight'), findsNothing);
      expect(find.byType(LogWeightView), findsOneWidget);
    });
  });
}
