import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:purchases_repository/purchases_repository.dart';

part 'coach_state.dart';

/// What the coach screen is opened with (Swift `CoachDelegate`).
final class const CoachRequest({
  /// Where it was opened from.
  final CoachContext context = CoachContext.today,

  /// A stored chat to continue; null starts a new one.
  final CoachChat? chat,

  /// Opened over the screen it was asked from, it closes; pushed from the
  /// chat list, it goes back instead.
  final bool showsCloseButton = true,
}) {
  /// Creates a [CoachRequest].
  this;

  /// [chat] opened from the chat list (`CoachChatsPresenter
  /// .onChatPressed`): about what the chat was about, or [fallback]'s kind
  /// when it was saved without one.
  factory forChat(CoachChat chat, CoachContext fallback) => CoachRequest(
    context: CoachContext(
      kind:
          CoachContextKind.values
              .where((kind) => kind.value == chat.contextKind)
              .firstOrNull ??
          fallback.kind,
    ),
    chat: chat,
    showsCloseButton: false,
  );
}

/// The AI coach's chat (Swift `CoachPresenter`): premium, then consent,
/// then the conversation, with each answer streamed as it arrives.
///
/// The conversation is the user's health data, so analytics carry the
/// context and never the text.
class CoachCubit extends Cubit<CoachState> {
  /// [_uid] is the signed-in user.
  new({
    required this._uid,
    required this._request,
    required this._coach,
    required this._purchases,
    required this._analytics,
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : super(
         CoachState(
           messages: _request.chat?.messages ?? const [],
           savedMessageCount: _request.chat?.messages.length ?? 0,
           chatId: _request.chat?.id,
           chatTitle: _request.chat?.title,
           remainingToday: _coach.remainingToday(_uid),
         ),
       );

  final String _uid;
  final CoachRequest _request;
  final CoachRepository _coach;
  final PurchasesRepository _purchases;
  final AnalyticsRepository _analytics;
  final DateTime Function() _now;
  final String Function() _newId;
  StreamSubscription<List<CoachChat>>? _chats;

  /// The saved chats as last read: the function saves an exchange before
  /// it answers, so a new chat's title can be here before its id is.
  List<CoachChat> _saved = const [];

  String? _savedTitle(String? chatId) =>
      _saved.where((chat) => chat.id == chatId).firstOrNull?.title ??
      state.chatTitle;

  Map<String, Object?> get _contextParameter => {
    'context': _request.context.kind.value,
  };

  /// `CoachView_Appear`, then the gate, read once (`onViewAppear`): only
  /// this screen moves it after that, so a refusal from the function can
  /// move it back. Also follows the saved chats for the chat's title.
  Future<void> appeared() async {
    _analytics.appear('CoachView', _contextParameter);
    _chats ??= _coach.watchChats(_uid).listen((chats) {
      _saved = chats;
      emit(state.copyWith(chatTitle: () => _savedTitle(state.chatId)));
    }, onError: (Object _) {});
    if (!_purchases.state.isPremiumWith()) {
      emit(state.copyWith(gate: CoachGate.premium));
      return;
    }
    final consented = await _coach.watchConsent(_uid).first;
    if (isClosed) return;
    emit(state.copyWith(gate: consented ? CoachGate.chat : CoachGate.consent));
  }

  /// `CoachView_Disappear`.
  void disappeared() => _analytics.disappear('CoachView');

  /// See Plans on the premium gate.
  void seePlansPressed() => _analytics.analytic('CoachView_SeePlans_Press');

  /// Allow and Continue: records consent, then opens the chat. A failure
  /// is severe and leaves the gate up.
  Future<void> consentAccepted() async {
    if (state.isGivingConsent) return;
    emit(state.copyWith(isGivingConsent: true));
    _analytics.analytic('CoachView_Consent_Start');
    try {
      await _coach.giveConsent(_uid);
      _analytics.analytic('CoachView_Consent_Success');
      emit(state.copyWith(isGivingConsent: false, gate: CoachGate.chat));
    } on Object catch (error) {
      _analytics.severe('CoachView_Consent_Fail', error);
      emit(
        state.copyWith(
          isGivingConsent: false,
          consentFailures: state.consentFailures + 1,
        ),
      );
    }
  }

  /// Not Now; the view closes the coach.
  void consentDeclined() => _analytics.analytic('CoachView_Consent_Declined');

  /// The message field as typed.
  void draftChanged(String draft) => emit(state.copyWith(draft: draft));

  /// A suggested question, sent as it is.
  Future<void> suggestionPressed(String question) {
    emit(state.copyWith(draft: question));
    return sendPressed();
  }

  /// Sends the trimmed draft. The question shows at once and the answer
  /// streams in after it. On a failure the message comes off the
  /// conversation and goes back in the field to try again; a refusal for
  /// consent or premium goes back to that gate instead of an error.
  Future<void> sendPressed() async {
    final text = state.draft.trim();
    if (text.isEmpty || state.isSending) return;
    final pending = CoachMessage(
      id: _newId(),
      role: CoachMessageRole.user,
      text: text,
      createdAt: _now(),
    );
    emit(
      state.copyWith(
        draft: '',
        draftRevision: state.draftRevision + 1,
        failure: () => null,
        isSending: true,
        streamingText: () => '',
        streamingBlocks: const [],
        messages: [...state.messages, pending],
      ),
    );
    _analytics.analytic('CoachView_Send_Start', {
      ..._contextParameter,
      'is_new_chat': state.chatId == null,
    });
    try {
      await for (final event in _coach.send(
        _uid,
        text,
        chatId: state.chatId,
        context: _request.context,
      )) {
        if (isClosed) return;
        switch (event) {
          case CoachText(:final text):
            emit(
              state.copyWith(
                streamingText: () => (state.streamingText ?? '') + text,
              ),
            );
          case CoachBlockShown(:final block):
            emit(
              state.copyWith(
                streamingBlocks: [...state.streamingBlocks, block],
              ),
            );
          case CoachFinished(:final chatId, :final messageId, :final text):
            emit(
              state.copyWith(
                chatId: () => chatId,
                chatTitle: () => _savedTitle(chatId),
                remainingToday: event.remainingToday,
                streamingBlocks: const [],
                messages: [
                  ...state.messages,
                  CoachMessage(
                    id: messageId,
                    role: CoachMessageRole.assistant,
                    text: text,
                    createdAt: _now(),
                    blocks: event.blocks.isEmpty ? null : event.blocks,
                  ),
                ],
              ),
            );
        }
      }
      _analytics.analytic('CoachView_Send_Success');
      if (isClosed) return;
      emit(state.copyWith(isSending: false, streamingText: () => null));
    } on Object catch (error) {
      final failure = error is CoachException
          ? error.failure
          : CoachFailure.unavailable;
      _analytics.trackEvent(
        AnalyticsEvent(
          'CoachView_Send_Fail',
          parameters: {'reason': failure.name},
          type: LogType.warning,
        ),
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isSending: false,
          streamingText: () => null,
          streamingBlocks: const [],
          messages: [
            for (final message in state.messages)
              if (message.id != pending.id) message,
          ],
          draft: text,
          draftRevision: state.draftRevision + 1,
          sendFailures: state.sendFailures + 1,
          remainingToday: failure == CoachFailure.dailyLimitReached ? 0 : null,
          gate: switch (failure) {
            CoachFailure.consentRequired => CoachGate.consent,
            CoachFailure.premiumRequired => CoachGate.premium,
            _ => null,
          },
          failure: () => switch (failure) {
            CoachFailure.consentRequired ||
            CoachFailure.premiumRequired => null,
            _ => failure,
          },
        ),
      );
    }
  }

  /// New Chat from the menu: the next message starts a chat of its own.
  void newChatPressed() {
    _analytics.analytic('CoachView_NewChat_Press');
    emit(
      state.copyWith(
        chatId: () => null,
        chatTitle: () => null,
        messages: const [],
        savedMessageCount: 0,
        failure: () => null,
      ),
    );
  }

  /// Chats from the menu; the view opens the list.
  void chatsPressed() => _analytics.analytic('CoachView_Chats_Press');

  @override
  Future<void> close() async {
    await _chats?.cancel();
    await super.close();
  }
}
