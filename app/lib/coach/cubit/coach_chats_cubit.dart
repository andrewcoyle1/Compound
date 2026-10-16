import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';

/// What the chat list has to tell the user once.
enum CoachChatsNotice {
  /// A chat could not be deleted.
  deleteFailed,

  /// Consent was withdrawn and the chats deleted.
  withdrawn,

  /// Withdrawing failed.
  withdrawFailed,
}

/// The coach's saved chats and the permission behind them.
final class const CoachChatsState({
  /// Newest first; null until read.
  final List<CoachChat>? chats,
  final bool hasConsented = false,
  final bool isWithdrawing = false,
  final CoachChatsNotice? notice,

  /// Bumped with every [notice], so the same one twice shows twice.
  final int noticeId = 0,
}) extends Equatable {
  CoachChatsState copyWith({
    List<CoachChat>? chats,
    bool? hasConsented,
    bool? isWithdrawing,
    CoachChatsNotice? notice,
  }) => CoachChatsState(
    chats: chats ?? this.chats,
    hasConsented: hasConsented ?? this.hasConsented,
    isWithdrawing: isWithdrawing ?? this.isWithdrawing,
    notice: notice ?? this.notice,
    noticeId: notice == null ? noticeId : noticeId + 1,
  );

  @override
  List<Object?> get props => [
    chats,
    hasConsented,
    isWithdrawing,
    notice,
    noticeId,
  ];
}

/// The coach's saved chats (Swift `CoachChatsPresenter`): reached from the
/// coach's menu and from Settings. The function writes the chats; this
/// only reads and deletes them. Withdrawing the permission deletes every
/// chat, as Swift does.
class CoachChatsCubit extends Cubit<CoachChatsState> {
  /// [_uid] is the signed-in user.
  new({required this._uid, required this._coach, required this._analytics})
    : super(const CoachChatsState());

  final String _uid;
  final CoachRepository _coach;
  final AnalyticsRepository _analytics;
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Follows the chats and the consent flag.
  void started() {
    _subscriptions.addAll([
      _coach
          .watchChats(_uid)
          .listen(
            (chats) => emit(state.copyWith(chats: chats)),
            onError: (Object _) => emit(state.copyWith(chats: const [])),
          ),
      _coach
          .watchConsent(_uid)
          .listen(
            (consented) => emit(state.copyWith(hasConsented: consented)),
            onError: (Object _) {},
          ),
    ]);
  }

  /// `CoachChatsView_Appear`.
  void appeared() => _analytics.appear('CoachChatsView');

  /// `CoachChatsView_Disappear`.
  void disappeared() => _analytics.disappear('CoachChatsView');

  /// A chat tapped; the view opens it.
  void chatPressed() => _analytics.analytic('CoachChatsView_Chat_Press');

  /// New Chat; the view opens the coach.
  void newChatPressed() => _analytics.analytic('CoachChatsView_NewChat_Press');

  /// Deletes [chat]; a failure is a warning and a notice.
  Future<void> deleteChat(CoachChat chat) async {
    _analytics.analytic('CoachChatsView_DeleteChat_Start');
    try {
      await _coach.deleteChat(_uid, chat.id);
      _analytics.analytic('CoachChatsView_DeleteChat_Success');
    } on Object catch (error) {
      _analytics.trackEvent(
        AnalyticsEvent(
          'CoachChatsView_DeleteChat_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.warning,
        ),
      );
      if (!isClosed) {
        emit(state.copyWith(notice: CoachChatsNotice.deleteFailed));
      }
    }
  }

  /// Withdraw, once confirmed: consent off, then every chat deleted.
  Future<void> withdrawConfirmed() async {
    if (state.isWithdrawing) return;
    emit(state.copyWith(isWithdrawing: true));
    _analytics.analytic('CoachChatsView_Withdraw_Start');
    CoachChatsNotice notice;
    try {
      await _coach.withdrawConsent(_uid);
      _analytics.analytic('CoachChatsView_Withdraw_Success');
      notice = CoachChatsNotice.withdrawn;
    } on Object catch (error) {
      _analytics.severe('CoachChatsView_Withdraw_Fail', error);
      notice = CoachChatsNotice.withdrawFailed;
    }
    if (isClosed) return;
    emit(state.copyWith(isWithdrawing: false, notice: notice));
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await super.close();
  }
}
