import 'package:app_ui/app_ui.dart';
import 'package:compound/widgets/calendar/calendar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  // Saturday 14 March 2026; en weeks start on Sunday, so 8–14 March.
  final today = DateTime(2026, 3, 14);
  late AnalyticsRecorder analytics;
  late CalendarHeaderCubit cubit;
  late List<DateTime> pressed;

  setUp(() {
    analytics = AnalyticsRecorder();
    cubit = CalendarHeaderCubit(analytics: analytics, today: today);
    pressed = [];
  });

  tearDown(() => cubit.close());

  final markers = <String, CalendarDayMarker>{
    '2026-03-09': const SessionsMarker(['#FF0000', null, '#0000FF']),
    '2026-03-10': const SessionsMarker([null]),
    '2026-03-11': const GoalProgressMarker(value: 2650, goal: 2200, grace: 100),
    '2026-03-12': const GoalProgressMarker(value: 2250, goal: 2200, grace: 100),
    '2026-03-13': const GoalProgressMarker(value: 1100, goal: 2200, grace: 100),
    '2026-03-08': const CountMarker(12),
  };

  Future<void> pump(WidgetTester tester, {DateTime? selectedDay}) =>
      tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  CalendarHeader(
                    today: today,
                    markers: markers,
                    selectedDay: selectedDay,
                    onDaySelected: pressed.add,
                  ),
                  TextButton(
                    onPressed: () => CalendarHeader.showCalendar(
                      context,
                      today: today,
                      markers: markers,
                      selectedDay: selectedDay,
                      onDaySelected: pressed.add,
                    ),
                    child: const Text('open'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  group(CalendarHeader, () {
    testWidgets('shows the week with its markers and badges', (tester) async {
      await pump(tester, selectedDay: DateTime(2026, 3, 12));
      expect(find.text('8'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('9+'), findsOneWidget);
      expect(find.bySemanticsLabel('Wednesday, March 11'), findsOneWidget);
      final semantics = tester.getSemantics(
        find.bySemanticsLabel('Saturday, March 14'),
      );
      expect(semantics.value, 'Today');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Monday, March 9')).value,
        '3 logged',
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Wednesday, March 11')).value,
        '120% of goal, Over goal',
      );
    });

    testWidgets('a tap tells the host and the cubit', (tester) async {
      await pump(tester);
      await tester.tap(find.text('10'));
      expect(pressed, [DateTime(2026, 3, 10)]);
      expect(cubit.state.focusedDay, DateTime(2026, 3, 10));
      expect(analytics.names, [
        'CalendarHeader_DateSelectionFunction_Triggered',
      ]);
    });

    testWidgets('swipes page weeks and Return to Today comes back', (
      tester,
    ) async {
      await pump(tester);
      expect(find.bySemanticsLabel('Today'), findsNothing);
      await tester.fling(find.text('10'), const Offset(300, 0), 800);
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      // Today is ahead: the button sits at the end.
      expect(find.bySemanticsLabel('Today'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Today'));
      await tester.pumpAndSettle();
      expect(find.text('14'), findsOneWidget);
      expect(analytics.names, ['CalendarHeader_ReturnedToToday']);

      await tester.fling(find.text('10'), const Offset(-300, 0), 800);
      await tester.pumpAndSettle();
      expect(find.text('21'), findsOneWidget);
      expect(find.bySemanticsLabel('Today'), findsOneWidget);
    });

    testWidgets('screen readers page with actions', (tester) async {
      await pump(tester);
      final node = tester.getSemantics(find.byType(CalendarHeader));
      expect(node.getSemanticsData().customSemanticsActionIds, hasLength(2));
      cubit.weekMoved(1);
      await tester.pump();
      expect(find.text('21'), findsOneWidget);
    });

    testWidgets('follows a selection made elsewhere when off screen', (
      tester,
    ) async {
      await pump(tester, selectedDay: today);
      await pump(tester, selectedDay: DateTime(2026, 3, 13));
      expect(cubit.state.shownDay, today);
      await pump(tester, selectedDay: DateTime(2026, 2, 2));
      expect(cubit.state.shownDay, DateTime(2026, 2, 2));
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('the month picker hands back the day picked', (tester) async {
      await pump(tester, selectedDay: today);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('March 2026'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Friday, March 20'));
      await tester.pumpAndSettle();
      expect(find.text('Calendar'), findsNothing);
      expect(pressed, [DateTime(2026, 3, 20)]);
      expect(cubit.state.focusedDay, DateTime(2026, 3, 20));
      expect(analytics.names, [
        'CalendarHeader_OpenLargeCalendar',
        'CalendarView_Appear',
        'CalendarView_Disappear',
        'CalendarHeader_DatePickedFromLargeCalendar',
      ]);
    });

    testWidgets('the month picker scrolls to today, and closes', (
      tester,
    ) async {
      await pump(tester, selectedDay: DateTime(2025, 1, 5));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('January 2025'), findsOneWidget);
      await tester.tap(find.text('Today').last);
      await tester.pumpAndSettle();
      expect(find.text('March 2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(pressed, isEmpty);
      expect(analytics.names.last, 'CalendarView_Disappear');
    });
  });

  group(CalendarSheet, () {
    test('offers 18 months back to 6 ahead', () {
      final months = CalendarSheet.monthsAround(today);
      expect(months, hasLength(25));
      expect(months.first, DateTime(2024, 9));
      expect(months.last, DateTime(2026, 9));
    });
  });

  group(CalendarRingPainter, () {
    test('repaints when what it draws changes', () {
      CalendarRingPainter painter({
        bool selected = false,
        List<Color> colours = const [Colors.red],
      }) => CalendarRingPainter(
        marker: const CountMarker(1),
        isSelected: selected,
        fill: Colors.grey,
        colours: colours,
      );
      expect(painter().shouldRepaint(painter()), isFalse);
      expect(painter().shouldRepaint(painter(selected: true)), isTrue);
      expect(
        painter().shouldRepaint(painter(colours: const [Colors.blue])),
        isTrue,
      );
      expect(painter().shouldRepaint(painter(colours: const [])), isTrue);
    });

    test('outlines a wide capsule from the top centre too', () {
      final path = CalendarRingPainter.outlineOf(
        const Rect.fromLTWH(0, 0, 100, 40),
        20,
      );
      expect(path.computeMetrics().first.length, greaterThan(200));
    });
  });
}
