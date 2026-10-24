import 'dart:async';
import 'dart:math' as math;

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

  /// Sends the trimmed draft.
  Future<void> sendPressed() async {
    final text = state.draft.trim();
    if (text.isEmpty || state.isSending) return;
    emit(state.copyWith(draft: '', draftRevision: state.draftRevision + 1));
    await _ask(text);
  }

  /// Retry under a failed or stopped question: asks it again, as the
  /// newest message.
  Future<void> retryPressed(String questionId) async {
    final question = state.messages
        .where((message) => message.id == questionId)
        .firstOrNull;
    if (question == null || state.isSending) return;
    _analytics.analytic('CoachView_Retry_Press', _contextParameter);
    emit(
      state.copyWith(
        messages: [
          for (final message in state.messages)
            if (message.id != questionId) message,
        ],
        questions: {...state.questions}..remove(questionId),
      ),
    );
    await _ask(question.text);
  }

  /// Regenerate, on the latest answer: asks its question again with
  /// `regenerate`, so the new answer replaces it in the chat. The old answer
  /// is hidden while the new one streams, and comes back if it fails or is
  /// stopped.
  Future<void> regeneratePressed() async {
    if (!state.canRegenerate) return;
    _analytics.analytic('CoachView_Regenerate_Press', _contextParameter);
    final messages = state.messages;
    _replaced = (messages.last, state.savedMessageCount);
    emit(
      state.copyWith(
        messages: messages.sublist(0, messages.length - 1),
        savedMessageCount: math.min(
          state.savedMessageCount,
          messages.length - 1,
        ),
      ),
    );
    await _ask(messages[messages.length - 2].text, regenerating: true);
  }

  /// The answer a regeneration hides, and how many messages were saved
  /// with it, while the new one streams.
  (CoachMessage, int)? _replaced;

  /// Ends a regeneration that got no new answer: [from], with the question
  /// no longer pending, then the answer it hid back in place. False when
  /// nothing is being regenerated.
  ///
  /// In two steps, so the old answer coming back is not announced as a new
  /// one: the view announces an answer that arrives as answering ends.
  bool _restored(CoachState from) {
    final replaced = _replaced;
    if (replaced == null) return false;
    _replaced = null;
    final (reply, savedMessageCount) = replaced;
    emit(from.copyWith(questions: {...from.questions}..remove(_answering)));
    emit(
      state.copyWith(
        messages: [...state.messages, reply],
        savedMessageCount: savedMessageCount,
      ),
    );
    return true;
  }

  /// Stop, while the coach answers: drops what has streamed and leaves the
  /// question marked stopped, with Retry; or for a regeneration, brings the
  /// old answer back. The quota stays spent.
  void stopPressed() {
    final questionId = _answering;
    if (questionId == null) return;
    _analytics.analytic('CoachView_Stop_Press', _contextParameter);
    final stopped = state.copyWith(
      questions: {
        ...state.questions,
        questionId: const CoachQuestionStatus.stopped(),
      },
      streamingText: () => null,
      streamingBlocks: const [],
    );
    if (!_restored(stopped)) emit(stopped);
    _endAnswer();
  }

  /// Copy, from a message's actions; the view copies it.
  void copyPressed(CoachMessageRole role) => _analytics.analytic(
    'CoachView_Copy_Press',
    {..._contextParameter, 'role': role.name},
  );

  /// Thumbs up or down on an answer. Never the text.
  void feedbackGiven({required bool helpful}) => _analytics.analytic(
    'CoachView_Feedback',
    {..._contextParameter, 'rating': helpful ? 'up' : 'down'},
  );

  /// The question being answered, while one is.
  String? _answering;
  StreamSubscription<CoachStreamEvent>? _answer;
  Completer<void>? _answered;

  /// Asks [text]. The question shows at once and the answer streams in
  /// after it. On a failure the question stays, marked failed, to retry; a
  /// refusal for consent or premium takes it off, puts it back in the
  /// field and goes back to that gate instead.
  ///
  /// [regenerating] asks the last message, already shown, again.
  Future<void> _ask(String text, {bool regenerating = false}) {
    final question = regenerating
        ? state.messages.last
        : CoachMessage(
            id: _newId(),
            role: CoachMessageRole.user,
            text: text,
            createdAt: _now(),
          );
    emit(
      state.copyWith(
        questions: {
          ...state.questions,
          question.id: const CoachQuestionStatus.answering(),
        },
        streamingText: () => '',
        streamingBlocks: const [],
        messages: regenerating ? null : [...state.messages, question],
      ),
    );
    _analytics.analytic('CoachView_Send_Start', {
      ..._contextParameter,
      'is_new_chat': state.chatId == null,
    });
    final answered = _answered = Completer<void>();
    _answering = question.id;
    _answer = _coach
        .send(
          _uid,
          text,
          chatId: state.chatId,
          context: _request.context,
          regenerate: regenerating,
        )
        .listen(
          _received,
          onError: (Object error) => _failed(question, error),
          onDone: () {
            if (state.questions.containsKey(question.id)) {
              // Ended without an answer.
              return _failed(question, CoachFailure.unavailable);
            }
            _analytics.analytic('CoachView_Send_Success');
            _endAnswer();
          },
          cancelOnError: true,
        );
    return answered.future;
  }

  /// The answering question, running [tool]: text or a block means the
  /// last tool is done.
  Map<String, CoachQuestionStatus> _running([String? tool]) => {
    ...state.questions,
    ?_answering: CoachQuestionStatus.answering(tool),
  };

  void _received(CoachStreamEvent event) {
    switch (event) {
      case CoachStatus(:final tool):
        emit(state.copyWith(questions: _running(tool)));
      case CoachText(:final text):
        emit(
          state.copyWith(
            questions: _running(),
            streamingText: () => (state.streamingText ?? '') + text,
          ),
        );
      case CoachBlockShown(:final block):
        emit(
          state.copyWith(
            questions: _running(),
            streamingBlocks: [...state.streamingBlocks, block],
          ),
        );
      case CoachFinished(:final chatId, :final messageId, :final text):
        _replaced = null;
        emit(
          state.copyWith(
            chatId: () => chatId,
            chatTitle: () => _savedTitle(chatId),
            remainingToday: event.remainingToday,
            questions: {...state.questions}..remove(_answering),
            streamingText: () => null,
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

  void _failed(CoachMessage question, Object error) {
    final failure = switch (error) {
      CoachException(:final failure) => failure,
      CoachFailure() => error,
      _ => CoachFailure.unavailable,
    };
    _analytics.trackEvent(
      AnalyticsEvent(
        'CoachView_Send_Fail',
        parameters: {'reason': failure.name},
        type: LogType.warning,
      ),
    );
    final gate = switch (failure) {
      CoachFailure.consentRequired => CoachGate.consent,
      CoachFailure.premiumRequired => CoachGate.premium,
      _ => null,
    };
    final common = state.copyWith(
      streamingText: () => null,
      streamingBlocks: const [],
      sendFailures: state.sendFailures + 1,
      remainingToday: failure == CoachFailure.dailyLimitReached ? 0 : null,
    );
    // A regeneration that failed keeps the old answer, and says so unless
    // a gate takes over.
    final restored = _restored(
      common.copyWith(
        gate: gate,
        regenerateFailures: gate == null ? state.regenerateFailures + 1 : null,
      ),
    );
    _endAnswer();
    if (restored) return;
    emit(
      gate == null
          ? common.copyWith(
              questions: {
                ...state.questions,
                question.id: CoachQuestionStatus.failed(failure),
              },
            )
          // The gate's way: the question goes back in the field.
          : common.copyWith(
              gate: gate,
              questions: {...state.questions}..remove(question.id),
              messages: [
                for (final message in state.messages)
                  if (message.id != question.id) message,
              ],
              draft: question.text,
              draftRevision: state.draftRevision + 1,
            ),
    );
  }

  /// Lets go of the answer: the stream is cancelled (not awaited, as a
  /// generator only stops at its next chunk) and [_ask]'s future completes.
  void _endAnswer() {
    unawaited(_answer?.cancel());
    _answer = null;
    _answering = null;
    if (_answered case final answered? when !answered.isCompleted) {
      answered.complete();
    }
  }

  /// New Chat from the menu: the next message starts a chat of its own.
  void newChatPressed() {
    _analytics.analytic('CoachView_NewChat_Press');
    _replaced = null;
    emit(
      state.copyWith(
        chatId: () => null,
        chatTitle: () => null,
        messages: const [],
        savedMessageCount: 0,
        questions: const {},
      ),
    );
  }

  /// Chats from the menu; the view opens the list.
  void chatsPressed() => _analytics.analytic('CoachView_Chats_Press');

  @override
  Future<void> close() async {
    _endAnswer();
    await _chats?.cancel();
    await super.close();
  }
}
