import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/app/document_id.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// What Timeline Actions has to tell the user.
enum TimelineDayAlert {
  /// Copy Day on a day with nothing logged.
  nothingToCopy,

  /// Clear Day on a day with nothing logged.
  nothingToClear,

  /// Clear Day on a day with meals: confirm before deleting.
  confirmClear,

  /// A copy failed partway.
  copyFailed,

  /// A clear failed partway.
  clearFailed,
}

/// Copying or clearing the timeline's day.
final class const TimelineDayState({
  /// The day's meals, in the order they were eaten.
  final List<MealLogModel> meals = const [],

  /// Set while a copy or clear is writing, so a second tap cannot run it
  /// twice.
  final bool isWorking = false,

  /// Set once a copy or clear has finished; the sheet closes.
  final bool done = false,

  /// The latest thing to tell the user, and how many there have been, so
  /// the same alert twice still shows twice.
  final TimelineDayAlert? alert,
  final int alertCount = 0,
}) extends Equatable {
  TimelineDayState copyWith({
    List<MealLogModel>? meals,
    bool? isWorking,
    bool? done,
    TimelineDayAlert? alert,
  }) => TimelineDayState(
    meals: meals ?? this.meals,
    isWorking: isWorking ?? this.isWorking,
    done: done ?? this.done,
    alert: alert ?? this.alert,
    alertCount: alert == null ? alertCount : alertCount + 1,
  );

  @override
  List<Object?> get props => [meals, isWorking, done, alert, alertCount];
}

/// Timeline Actions' Copy Day and Clear Day (Swift
/// `TimelineActionsPresenter`), on `day`, the day the timeline shows, never
/// today unless that is the day shown. Its toggles are a
/// `FoodLogSettingsCubit`, which also logs the screen.
class TimelineDayCubit extends Cubit<TimelineDayState> {
  /// `uid` is the signed-in user, who owns the copies; signed out, nothing
  /// is copied.
  new({
    required this._uid,
    required this._day,
    required this._nutrition,
    required this._analytics,
    this._newId = newDocumentId,
  }) : super(const TimelineDayState()) {
    final uid = _uid;
    if (uid == null) return;
    _subscription = _nutrition
        .watchMeals(uid)
        .listen(
          (meals) =>
              emit(state.copyWith(meals: mealsOnDay(meals, dayKeyOf(_day)))),
          onError: (Object error) => _analytics.trackEvent(
            AnalyticsEvent(
              'TimelineActionsView_GetMeals_Fail',
              parameters: {'error_description': '$error'},
              type: LogType.warning,
            ),
          ),
        );
  }

  /// The day acted on, at local midnight.
  final DateTime _day;
  final String? _uid;
  final NutritionRepository _nutrition;
  final AnalyticsRepository _analytics;
  final String Function() _newId;
  StreamSubscription<List<MealLogModel>>? _subscription;

  /// Where Copy Day's picker opens: the day after, since the usual copy is
  /// "same as yesterday" (`onCopyDayPressed`).
  DateTime get defaultCopyDestination =>
      DateTime(_day.year, _day.month, _day.day + 1);

  /// Re-logs the day's meals on [destination] (`onCopyDayConfirmed`): each
  /// a new meal with a fresh id, its foods and notes, at its own time of
  /// day.
  Future<void> copyDay(DateTime destination) async {
    final uid = _uid;
    if (state.isWorking || uid == null) return;
    final meals = state.meals;
    if (meals.isEmpty) {
      emit(state.copyWith(alert: TimelineDayAlert.nothingToCopy));
      return;
    }
    final parameters = {'meal_count': meals.length};
    _analytics.analytic('TimelineActionsView_CopyDay', parameters);
    emit(state.copyWith(isWorking: true));
    try {
      for (final meal in meals) {
        final time = meal.date.toLocal();
        final date = DateTime(
          destination.year,
          destination.month,
          destination.day,
          time.hour,
          time.minute,
        );
        await _nutrition.saveMeal(
          MealLogModel(
            mealId: _newId(),
            authorId: uid,
            dayKey: dayKeyOf(date),
            date: date,
            items: meal.items,
            notes: meal.notes,
          ),
        );
      }
      _analytics.analytic('TimelineActionsView_CopyDay_Success', parameters);
      emit(state.copyWith(isWorking: false, done: true));
    } on Object catch (error) {
      _analytics.severe('TimelineActionsView_Action_Fail', error);
      emit(
        state.copyWith(isWorking: false, alert: TimelineDayAlert.copyFailed),
      );
    }
  }

  /// Clear Day (`onClearDayPressed`): says so when there is nothing to
  /// clear, and otherwise asks first.
  void clearDayPressed() => emit(
    state.copyWith(
      alert: state.meals.isEmpty
          ? TimelineDayAlert.nothingToClear
          : TimelineDayAlert.confirmClear,
    ),
  );

  /// Deletes the day's meals, once confirmed (`clearDay`).
  Future<void> clearDay() async {
    final uid = _uid;
    final meals = state.meals;
    if (state.isWorking || uid == null || meals.isEmpty) return;
    final parameters = {'meal_count': meals.length};
    _analytics.analytic('TimelineActionsView_ClearDay', parameters);
    emit(state.copyWith(isWorking: true));
    try {
      for (final meal in meals) {
        await _nutrition.deleteMeal(meal.authorId, meal.mealId);
      }
      _analytics.analytic('TimelineActionsView_ClearDay_Success', parameters);
      emit(state.copyWith(isWorking: false, done: true));
    } on Object catch (error) {
      _analytics.severe('TimelineActionsView_Action_Fail', error);
      emit(
        state.copyWith(isWorking: false, alert: TimelineDayAlert.clearFailed),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
