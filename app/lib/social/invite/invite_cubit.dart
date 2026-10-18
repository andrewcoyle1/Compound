import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound_models/compound_models.dart';
import 'package:connectivity_repository/connectivity_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:social_repository/social_repository.dart';

/// What the last invite action came to, for the app to act on.
sealed class InviteResult extends Equatable {
  const new();

  @override
  List<Object?> get props => [];
}

/// The viewer's invite is ready to share: `compound://join/<code>`.
final class const InviteShareReady(final String link) extends InviteResult {
  @override
  List<Object?> get props => [link];
}

/// The invite could not be read or created (`Couldn't create invite`).
final class const InviteShareFailed() extends InviteResult;

/// An invite was accepted: [inviter]'s profile opens with what happened.
final class const InviteAccepted(
  final UserModel inviter,
  final InviteAcceptance acceptance,
) extends InviteResult {
  @override
  List<Object?> get props => [inviter, acceptance];
}

/// Accepting failed (`Couldn't accept invite`), for [failure]'s reason, or
/// for none the user can act on.
final class const InviteAcceptFailed(final InviteFailure? failure)
    extends InviteResult {
  @override
  List<Object?> get props => [failure];
}

final class const InviteState({
  final InviteResult? result,

  /// Bumped with each [result], so the same one twice acts twice.
  final int resultId = 0,

  /// An invite is being read or accepted.
  final bool isBusy = false,
}) extends Equatable {
  @override
  List<Object?> get props => [result, resultId, isBusy];
}

/// Invites, app-wide: sharing the viewer's own link (Swift
/// `InviteShareFlow`) and accepting someone else's, from a
/// `compound://join/` link or a typed code (`InviteAcceptFlow`).
class InviteCubit extends Cubit<InviteState> {
  new({
    required this._social,
    required this._analytics,
    required this._connectivity,
  }) : super(const InviteState());

  final SocialRepository _social;
  final AnalyticsRepository _analytics;

  /// Both need the server: neither starts offline (`ensureOnline`).
  final ConnectivityRepository _connectivity;

  void _emit(InviteResult result) =>
      emit(InviteState(result: result, resultId: state.resultId + 1));

  /// Reads [uid]'s invite, creating it the first time, for the share sheet.
  /// [pressedEvent] names the button, as each Swift screen tracks its own.
  Future<void> shareRequested(String uid, {String? pressedEvent}) async {
    if (state.isBusy || !_connectivity.ensureOnline()) return;
    if (pressedEvent != null) {
      _analytics.trackEvent(AnalyticsEvent(pressedEvent));
    }
    emit(
      InviteState(result: state.result, resultId: state.resultId, isBusy: true),
    );
    try {
      final invite = await _social.myInvite(uid);
      _emit(InviteShareReady(inviteLink(invite.code)));
    } on Object catch (_) {
      _emit(const InviteShareFailed());
    }
  }

  /// Accepts invite [code] for [viewer] and reads the inviter's profile.
  Future<void> accept(String code, {required UserModel viewer}) async {
    if (state.isBusy || !_connectivity.ensureOnline()) return;
    _analytics.trackEvent(const AnalyticsEvent('Invite_Accept_Start'));
    emit(
      InviteState(result: state.result, resultId: state.resultId, isBusy: true),
    );
    try {
      final acceptance = await _social.acceptInvite(code);
      final inviter = (await _social.users([
        acceptance.inviterId,
      ], viewer: viewer)).firstOrNull;
      if (inviter == null) {
        throw const InviteException(InviteFailure.notFound);
      }
      _analytics.trackEvent(const AnalyticsEvent('Invite_Accept_Success'));
      _emit(InviteAccepted(inviter, acceptance));
    } on Object catch (error) {
      _analytics.trackEvent(
        const AnalyticsEvent('Invite_Accept_Fail', type: LogType.warning),
      );
      _emit(
        InviteAcceptFailed(error is InviteException ? error.failure : null),
      );
    }
  }

  /// `compound://join/<code>`, which `DeepLink.parse` reads back.
  static String inviteLink(String code) => 'compound://join/$code';
}
