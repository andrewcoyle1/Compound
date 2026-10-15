import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound_maths/compound_maths.dart' show weeklySessionGoal;
import 'package:equatable/equatable.dart';
import 'package:user_repository/user_repository.dart';

/// Where saving the goal is.
enum WeeklyGoalStatus { editing, saving, saved, failed }

final class const WeeklyGoalState({
  /// The goal shown as chosen: null until one has been saved, so the
  /// default 3 can still be picked.
  final int? selected,
  final WeeklyGoalStatus status = WeeklyGoalStatus.editing,
  final int failureId = 0,
}) extends Equatable {
  @override
  List<Object?> get props => [selected, status, failureId];
}

/// The weekly session goal (`WeeklyGoalPresenter`): picking a number is the
/// whole interaction, saving it and closing the sheet.
class WeeklyGoalCubit extends Cubit<WeeklyGoalState> {
  new({
    required this._users,
    required this._analytics,
    required this._uid,
    required int? savedGoal,
  }) : _saved = savedGoal == null ? null : weeklySessionGoal(savedGoal),
       super(
         WeeklyGoalState(
           selected: savedGoal == null ? null : weeklySessionGoal(savedGoal),
         ),
       );

  final UserRepository _users;
  final AnalyticsRepository _analytics;
  final String _uid;
  final int? _saved;

  void appeared() =>
      _analytics.trackScreenView(const AnalyticsEvent('WeeklyGoalView_Appear'));

  void disappeared() =>
      _analytics.trackEvent(const AnalyticsEvent('WeeklyGoalView_Disappear'));

  /// Saves [goal], clamped to 1–7.
  Future<void> goalSelected(int goal) async {
    if (state.status == WeeklyGoalStatus.saving) return;
    final clamped = weeklySessionGoal(goal);
    final parameters = {'weekly_session_goal': clamped};
    _analytics
      ..trackEvent(
        AnalyticsEvent('WeeklyGoalView_Save_Pressed', parameters: parameters),
      )
      ..trackEvent(const AnalyticsEvent('WeeklyGoalView_Save_Start'));
    emit(
      WeeklyGoalState(
        selected: clamped,
        status: WeeklyGoalStatus.saving,
        failureId: state.failureId,
      ),
    );
    try {
      await _users.updateUserFields(_uid, [
        UserField.weeklySessionGoal(clamped),
      ]);
      _analytics.trackEvent(
        AnalyticsEvent('WeeklyGoalView_Save_Success', parameters: parameters),
      );
      emit(
        WeeklyGoalState(
          selected: clamped,
          status: WeeklyGoalStatus.saved,
          failureId: state.failureId,
        ),
      );
    } on Object catch (error) {
      _analytics.trackEvent(
        AnalyticsEvent(
          'WeeklyGoalView_Save_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.severe,
        ),
      );
      emit(
        WeeklyGoalState(
          selected: _saved,
          status: WeeklyGoalStatus.failed,
          failureId: state.failureId + 1,
        ),
      );
    }
  }
}
