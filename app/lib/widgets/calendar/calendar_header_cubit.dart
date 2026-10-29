import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';

/// The calendar header's week on screen and the day last chosen (Swift
/// `CalendarHeaderPresenter` and the month picker's appear and disappear).
final class const CalendarHeaderState({
  /// The day at the strip's leading edge once it settles, or the day it
  /// is asked to bring into view; at local midnight.
  required final DateTime shownDay,

  /// The day last tapped or picked; null until one is.
  final DateTime? focusedDay,
}) extends Equatable {
  @override
  List<Object?> get props => [shownDay, focusedDay];
}

/// Tracks the header's days on screen and its use with Swift's event
/// names. The host decides what a chosen day does.
class CalendarHeaderCubit extends Cubit<CalendarHeaderState> {
  new({required this._analytics, required DateTime today})
    : super(CalendarHeaderState(shownDay: today));

  final AnalyticsRepository _analytics;

  /// A day was tapped in the strip.
  void dayPressed(DateTime day) {
    _analytics.info('CalendarHeader_DateSelectionFunction_Triggered');
    emit(CalendarHeaderState(shownDay: state.shownDay, focusedDay: day));
  }

  /// The strip settled with [day] at its leading edge, or should bring
  /// [day] into view.
  void dayShown(DateTime day) =>
      emit(CalendarHeaderState(shownDay: day, focusedDay: state.focusedDay));

  /// Return to Today: back to the week holding [today].
  void returnedToToday(DateTime today) {
    _analytics.info('CalendarHeader_ReturnedToToday');
    dayShown(today);
  }

  /// The month picker opened.
  void largeCalendarOpened() {
    _analytics
      ..info('CalendarHeader_OpenLargeCalendar')
      ..appear('CalendarView');
  }

  /// The month picker closed, with the day [picked] in it or none.
  void largeCalendarClosed(DateTime? picked) {
    _analytics.disappear('CalendarView');
    if (picked == null) return;
    _analytics.info('CalendarHeader_DatePickedFromLargeCalendar');
    emit(CalendarHeaderState(shownDay: picked, focusedDay: picked));
  }
}
