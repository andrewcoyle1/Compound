import 'package:bloc_test/bloc_test.dart';
import 'package:compound/widgets/calendar/calendar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Swift's `CalendarHeaderPresenterTests` where they apply: the strip pages
/// a week at a time here (#95), so its day-range cases have no counterpart.
void main() {
  final today = DateTime(2026, 3, 14);
  final day = DateTime(2026, 3, 11);
  late AnalyticsRecorder analytics;

  setUp(() => analytics = AnalyticsRecorder());

  CalendarHeaderCubit build() =>
      CalendarHeaderCubit(analytics: analytics, today: today);

  group(CalendarHeaderCubit, () {
    test('opens on today, nothing focused', () {
      expect(build().state, CalendarHeaderState(shownDay: today));
    });

    blocTest<CalendarHeaderCubit, CalendarHeaderState>(
      'pressing a day focuses it',
      build: build,
      act: (cubit) => cubit.dayPressed(day),
      expect: () => [CalendarHeaderState(shownDay: today, focusedDay: day)],
    );

    blocTest<CalendarHeaderCubit, CalendarHeaderState>(
      'pressing a day in the strip is tracked',
      build: build,
      act: (cubit) => cubit.dayPressed(day),
      verify: (_) => expect(analytics.names, [
        'CalendarHeader_DateSelectionFunction_Triggered',
      ]),
    );

    blocTest<CalendarHeaderCubit, CalendarHeaderState>(
      'returning to today is tracked and shows its week',
      build: build,
      act: (cubit) => cubit
        ..dayShown(DateTime(2026, 2, 28))
        ..returnedToToday(today),
      expect: () => [
        CalendarHeaderState(shownDay: DateTime(2026, 2, 28)),
        CalendarHeaderState(shownDay: today),
      ],
      verify: (_) =>
          expect(analytics.names, ['CalendarHeader_ReturnedToToday']),
    );

    blocTest<CalendarHeaderCubit, CalendarHeaderState>(
      "shows a day's week, keeping the focus",
      build: build,
      act: (cubit) => cubit
        ..dayPressed(day)
        ..dayShown(DateTime(2025, 12, 25)),
      expect: () => [
        CalendarHeaderState(shownDay: today, focusedDay: day),
        CalendarHeaderState(shownDay: DateTime(2025, 12, 25), focusedDay: day),
      ],
    );

    blocTest<CalendarHeaderCubit, CalendarHeaderState>(
      'a day picked in the month picker is focused and shown',
      build: build,
      act: (cubit) => cubit
        ..largeCalendarOpened()
        ..largeCalendarClosed(DateTime(2025, 1, 2)),
      expect: () => [
        CalendarHeaderState(
          shownDay: DateTime(2025, 1, 2),
          focusedDay: DateTime(2025, 1, 2),
        ),
      ],
      verify: (_) {
        expect(analytics.names, [
          'CalendarHeader_OpenLargeCalendar',
          'CalendarView_Appear',
          'CalendarView_Disappear',
          'CalendarHeader_DatePickedFromLargeCalendar',
        ]);
      },
    );

    blocTest<CalendarHeaderCubit, CalendarHeaderState>(
      'closing the month picker without a day changes nothing',
      build: build,
      act: (cubit) => cubit.largeCalendarClosed(null),
      expect: () => <CalendarHeaderState>[],
      verify: (_) => expect(analytics.names, ['CalendarView_Disappear']),
    );
  });
}
