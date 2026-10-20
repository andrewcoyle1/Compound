import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/social/logic/people.dart';
import 'package:compound_models/compound_models.dart';
import 'package:connectivity_repository/connectivity_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

/// Where sending is.
enum ShareSendStatus { editing, sending, sent, failed }

final class const ShareToFollowerState({
  /// Mutuals the viewer has not blocked, in the order they follow them.
  required final List<UserModel> recipients,
  final Set<String> selectedIds = const {},
  final ShareSendStatus status = ShareSendStatus.editing,

  /// Bumped with each failure.
  final int failureId = 0,
}) extends Equatable {
  bool get canSend =>
      selectedIds.isNotEmpty && status != ShareSendStatus.sending;

  ShareToFollowerState copyWith({
    Set<String>? selectedIds,
    ShareSendStatus? status,
    int? failureId,
  }) => ShareToFollowerState(
    recipients: recipients,
    selectedIds: selectedIds ?? this.selectedIds,
    status: status ?? this.status,
    failureId: failureId ?? this.failureId,
  );

  @override
  List<Object?> get props => [recipients, selectedIds, status, failureId];
}

/// Sends a template or mesocycle to mutuals (`ShareToFollowerPresenter`):
/// one share and one notification per recipient.
class ShareToFollowerCubit extends Cubit<ShareToFollowerState> {
  new({
    required this._social,
    required this._analytics,
    required this._connectivity,
    required this._viewer,
    required this._payload,
    required List<UserModel> following,
  }) : super(ShareToFollowerState(recipients: mutualsOf(_viewer, following)));

  final SocialRepository _social;
  final AnalyticsRepository _analytics;
  final ConnectivityRepository _connectivity;
  final UserModel _viewer;
  final SharePayload _payload;

  void appeared() => _analytics.trackScreenView(
    const AnalyticsEvent('ShareToFollowerView_Appear'),
  );

  void disappeared() => _analytics.trackEvent(
    const AnalyticsEvent('ShareToFollowerView_Disappear'),
  );

  /// Ticks or unticks [userId].
  void recipientPressed(String userId) {
    final selected = {...state.selectedIds};
    if (!selected.remove(userId)) selected.add(userId);
    emit(state.copyWith(selectedIds: selected));
  }

  /// Sends to everyone ticked, in the list's order.
  Future<void> sendPressed() async {
    if (!state.canSend || !_connectivity.ensureOnline()) return;
    final ids = [
      for (final user in state.recipients)
        if (state.selectedIds.contains(user.userId)) user.userId,
    ];
    emit(state.copyWith(status: ShareSendStatus.sending));
    _analytics.trackEvent(
      AnalyticsEvent(
        'ShareToFollowerView_Send_Start',
        parameters: {'kind': _payload.kind, 'recipient_count': ids.length},
      ),
    );
    try {
      await _social.sendShare(_payload, recipientIds: ids, viewer: _viewer);
      _analytics.trackEvent(
        const AnalyticsEvent('ShareToFollowerView_Send_Success'),
      );
      emit(state.copyWith(status: ShareSendStatus.sent));
    } on Object catch (error) {
      _analytics.trackEvent(
        AnalyticsEvent(
          'ShareToFollowerView_Send_Fail',
          parameters: {'error_description': '$error'},
          type: LogType.severe,
        ),
      );
      emit(
        state.copyWith(
          status: ShareSendStatus.failed,
          failureId: state.failureId + 1,
        ),
      );
    }
  }
}
