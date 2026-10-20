import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:body_repository/body_repository.dart';
import 'package:checkin_repository/checkin_repository.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound/today/logic/today_checklist.dart';
import 'package:compound_maths/compound_maths.dart'
    hide CheckInState, LoggingBreak;
import 'package:compound_models/compound_models.dart' show WorkoutTemplateModel;
import 'package:device_store/device_store.dart';
import 'package:equatable/equatable.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

part 'today_event.dart';
part 'today_state.dart';

/// The Today tab: the user's sessions, meals, diet plan, weigh-ins, steps,
/// step goal, profile and weight goal, each followed live, so logging
/// anything elsewhere shows here at once (Swift `TodayPresenter`).
class TodayBloc extends Bloc<TodayEvent, TodayState> {
  new({
    required this._workoutSessionRepository,
    required this._nutritionRepository,
    required this._bodyRepository,
    required this._userRepository,
    required this._analyticsRepository,
    required this._checkInRepository,
    required this._uid,
    required int firstWeekday,
    DeviceStore? store,
    DateTime Function() now = DateTime.now,
  }) : _store = store ?? InMemoryDeviceStore(),
       super(
         _initial(
           TodayState(uid: _uid, now: now(), firstWeekday: firstWeekday),
           store,
         ),
       ) {
    on<TodaySubscriptionRequested>(_onSubscriptionRequested);
    on<TodayWeeklyReviewOpened>((event, emit) {
      _analyticsRepository.trackEvent(
        const AnalyticsEvent('TodayView_WeeklyReview_Press'),
      );
      // Swift keeps the week opened, so the card stays away all week.
      _store.setString(
        weeklyReviewOpenedKey(_uid),
        weekStartOf(state.todayKey, firstWeekday: state.firstWeekday),
      );
      emit(state.copyWith(weeklyReviewOpened: true));
    });
    on<TodayStarterDismissed>((event, emit) {
      _analyticsRepository.analytic('TodayView_Starter_Dismiss', {
        'remaining': event.remaining,
      });
      // Swift keeps it in UserDefaults, per user, on the device.
      _store.setBool(starterDismissedKey(_uid), value: true);
      emit(state.copyWith(starterDismissed: true));
    });
    on<_TodayGoalChanged>(
      (event, emit) => emit(state.copyWith(goal: () => event.goal)),
    );
    on<TodayCheckInStarted>(
      (event, emit) => _analyticsRepository.trackEvent(
        const AnalyticsEvent('TodayView_CheckIn_Start'),
      ),
    );
    on<TodayCheckInSkipped>(_onCheckInSkipped);
    on<TodayChecklistItemPressed>(
      (event, emit) => _analyticsRepository.analytic(
        'TodayView_ChecklistItem_Press',
        {'item': event.item.kind},
      ),
    );
    on<TodayDayCompleted>(_onDayCompleted);
    on<TodayChecklistShown>(_onChecklistShown);
    on<TodayStepGoalSelected>(_onStepGoalSelected);
    on<TodaySocialPulsePressed>(
      (event, emit) =>
          _analyticsRepository.analytic('TodayView_SocialPulse_Press'),
    );
  }

  /// Where the day completed and the review card opened are kept.
  final DeviceStore _store;

  /// The key holding the day [uid] last completed, as Swift keys it.
  static String dayCompleteKey(String uid) => 'today_day_complete_$uid';

  /// The key holding the day [uid] last got the item of [kind] done
  /// ([ChecklistItem.kind]), as [dayCompleteKey] holds the whole list's.
  static String itemDoneKey(String uid, String kind) =>
      'today_item_done_${kind}_$uid';

  /// Whether the checklist has been shown since the screen opened: what is
  /// done by its first showing is recorded, not celebrated.
  var _checklistShown = false;

  /// The key holding the week [uid] last opened the review card in (its
  /// first day), as Swift keys it.
  static String weeklyReviewOpenedKey(String uid) =>
      'today_weekly_review_opened_$uid';

  /// The key holding whether [uid] hid the getting-started section, as
  /// Swift keys it.
  static String starterDismissedKey(String uid) =>
      'today_starter_dismissed_$uid';

  /// [state], with the review card opened if it was this week, and the
  /// getting-started section hidden if it was.
  static TodayState _initial(TodayState state, DeviceStore? store) =>
      state.copyWith(
        starterDismissed: store?.getBool(starterDismissedKey(state.uid)),
        weeklyReviewOpened:
            store?.getString(weeklyReviewOpenedKey(state.uid)) ==
            weekStartOf(state.todayKey, firstWeekday: state.firstWeekday),
      );

  /// Marks the day complete once per user and day
  /// (`onChecklistCompletionChanged`): `TodayView_DayComplete`, and the
  /// view's success haptic.
  void _onDayCompleted(TodayDayCompleted event, Emitter<TodayState> emit) {
    final key = dayCompleteKey(_uid);
    if (_store.getString(key) == state.todayKey) return;
    _store.setString(key, state.todayKey);
    _analyticsRepository.analytic('TodayView_DayComplete', {
      'item_count': event.itemCount,
    });
    emit(state.copyWith(dayCompletions: state.dayCompletions + 1));
  }

  /// Celebrates each item the checklist shows done for the first time
  /// today, once per user, item and day, on this device. Items already done
  /// when the screen first shows the list are only recorded, so reopening
  /// the app or the day never celebrates again.
  void _onChecklistShown(TodayChecklistShown event, Emitter<TodayState> emit) {
    final fresh = {
      for (final item in event.checklist.items)
        if (item.isDone &&
            _store.getString(itemDoneKey(_uid, item.kind)) != state.todayKey)
          item.kind,
    };
    for (final kind in fresh) {
      _store.setString(itemDoneKey(_uid, kind), state.todayKey);
    }
    final firstShowing = !_checklistShown;
    _checklistShown = true;
    if (firstShowing || fresh.isEmpty) return;
    emit(state.copyWith(celebrated: {...state.celebrated, ...fresh}));
  }

  /// Saves the chosen step goal (`onStepGoalSelected`). Choosing the goal
  /// already stored does nothing; choosing the age default when none is
  /// stored saves it, so it stays when the default changes. The goal shows
  /// at once and goes back if the write fails. Only the goal is written, so
  /// hidden sections changed on another device survive.
  Future<void> _onStepGoalSelected(
    TodayStepGoalSelected event,
    Emitter<TodayState> emit,
  ) async {
    final previous =
        state.analyticsSettings ?? AnalyticsSettings(authorId: _uid);
    if (previous.dailyStepGoal == event.goal) return;
    final settings = AnalyticsSettings(
      authorId: previous.authorId,
      id: previous.id,
      hiddenSectionIds: previous.hiddenSectionIds,
      dailyStepGoal: event.goal,
    );
    _analyticsRepository.analytic('TodayView_StepGoal_Start', {
      'goal': event.goal,
    });
    emit(state.copyWith(analyticsSettings: () => settings));
    try {
      await _bodyRepository.saveStepGoal(_uid, event.goal);
      emit(state.copyWith(stepGoalSaves: state.stepGoalSaves + 1));
    } on Object catch (error) {
      _analyticsRepository.severe('TodayView_StepGoal_Fail', error);
      emit(
        state.copyWith(
          analyticsSettings: () => previous,
          stepGoalFailures: state.stepGoalFailures + 1,
        ),
      );
    }
  }

  final WorkoutSessionRepository _workoutSessionRepository;
  final NutritionRepository _nutritionRepository;
  final BodyRepository _bodyRepository;
  final UserRepository _userRepository;
  final AnalyticsRepository _analyticsRepository;
  final CheckInRepository _checkInRepository;
  final String _uid;

  StreamSubscription<WeightGoal?>? _goalSubscription;
  String? _goalId;

  Future<void> _onSubscriptionRequested(
    TodaySubscriptionRequested event,
    Emitter<TodayState> emit,
  ) {
    _analyticsRepository.trackScreenView(
      const AnalyticsEvent('TodayView_Appear'),
    );
    _watchGoal(null);
    TodayState failed(Object _, StackTrace _) => state.copyWith(failed: true);
    // The checklist's inputs still to arrive, each once, in data or error.
    final unread = {
      'sessions',
      'meals',
      'measurements',
      'dietPlan',
      'steps',
      'settings',
      'user',
    };
    TodayState read(String input, TodayState next) =>
        unread.remove(input) && unread.isEmpty
        ? next.copyWith(checklistRead: true)
        : next;
    return Future.wait([
      emit.forEach(
        _workoutSessionRepository.watchSessions(_uid),
        onData: (sessions) =>
            read('sessions', state.copyWith(sessions: sessions)),
        onError: failed,
      ),
      emit.forEach(
        _nutritionRepository.watchMeals(_uid),
        onData: (meals) => read('meals', state.copyWith(meals: meals)),
        onError: failed,
      ),
      emit.forEach(
        _bodyRepository.watchMeasurements(_uid),
        onData: (measurements) =>
            read('measurements', state.copyWith(measurements: measurements)),
        onError: failed,
      ),
      // The rest are niceties: without them, no target, no steps item, the
      // default step goal, kilograms and no goal pace.
      emit.forEach(
        _nutritionRepository.watchDietPlan(_uid),
        onData: (plan) =>
            read('dietPlan', state.copyWith(dietPlan: () => plan)),
        onError: (_, _) =>
            read('dietPlan', state.copyWith(dietPlan: () => null)),
      ),
      emit.forEach(
        _bodyRepository.watchSteps(_uid),
        onData: (steps) => read('steps', state.copyWith(steps: steps)),
        onError: (_, _) => read('steps', state),
      ),
      emit.forEach(
        _bodyRepository.watchAnalyticsSettings(_uid),
        onData: (settings) =>
            read('settings', state.copyWith(analyticsSettings: () => settings)),
        onError: (_, _) => read('settings', state),
      ),
      // The check-in card's: without them, no card.
      emit.forEach(
        _checkInRepository.watchStrategySettings(_uid),
        onData: (settings) => state.copyWith(strategySettings: settings),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _checkInRepository.watchCheckInRecord(_uid),
        onData: (record) => state.copyWith(checkInRecord: () => record),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _checkInRepository.watchLoggingBreak(_uid),
        onData: (loggingBreak) =>
            state.copyWith(loggingBreak: () => loggingBreak),
        onError: (_, _) => state,
      ),
      emit.forEach(
        _userRepository.watchUser(_uid),
        onData: (user) {
          _watchGoal(user?.submittedCurrentGoalId);
          return read('user', state.copyWith(user: () => user));
        },
        onError: (_, _) => read('user', state),
      ),
    ]);
  }

  /// Optimistic, and puts the card back if the write does not land: a card
  /// that vanished on a failed write would look like a week dealt with.
  /// `TodayView_CheckIn_Skip` is the write's Start.
  Future<void> _onCheckInSkipped(
    TodayCheckInSkipped event,
    Emitter<TodayState> emit,
  ) async {
    final weekStart = state.dueCheckInWeekStart;
    if (weekStart == null) return;
    _analyticsRepository.trackEvent(
      const AnalyticsEvent('TodayView_CheckIn_Skip'),
    );
    emit(state.copyWith(checkInSkipped: true));
    try {
      await _checkInRepository.markCheckInSkipped(_uid, weekStart);
      _analyticsRepository.trackEvent(
        const AnalyticsEvent('TodayView_CheckIn_Skip_Success'),
      );
    } on Object catch (error) {
      _analyticsRepository.trackEvent(
        AnalyticsEvent(
          'TodayView_CheckIn_Skip_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.severe,
        ),
      );
      emit(
        state.copyWith(
          checkInSkipped: false,
          skipFailures: state.skipFailures + 1,
        ),
      );
    }
  }

  /// Follows the goal named by [goalId] (the uid's, without one), dropping
  /// the previous goal's stream when the id changes, as `GoalManager` does.
  void _watchGoal(String? goalId) {
    if (_goalSubscription != null && goalId == _goalId) return;
    _goalId = goalId;
    unawaited(_goalSubscription?.cancel());
    _goalSubscription = _bodyRepository
        .watchCurrentGoal(_uid, currentGoalId: goalId)
        .listen(
          (goal) => add(_TodayGoalChanged(goal)),
          onError: (Object _) => add(const _TodayGoalChanged(null)),
        );
  }

  @override
  Future<void> close() async {
    await _goalSubscription?.cancel();
    await super.close();
  }
}
