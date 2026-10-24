import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:checkin_repository/checkin_repository.dart' show localDayKey;
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:purchases_repository/purchases_repository.dart';

part 'coach_state.dart';

/// What the coach screen is opened with (Swift `CoachDelegate`).
final class const CoachRequest({
  /// Where it was opened from: what the next question is about.
  final CoachContext context = CoachContext.today,

  /// A stored chat to read; null opens today's chat. Today's chat opened
  /// here is today's chat too; any other is read-only.
  final CoachChat? chat,

  /// Opened over the screen it was asked from, it closes; pushed from the
  /// chat list, it goes back instead.
  final bool showsCloseButton = true,

  /// Opened only to ask permission, by Today's Turn On Coach: it closes
  /// once permission is given, back to Today's chat.
  final bool closesOnConsent = false,
}) {
  /// Creates a [CoachRequest].
  this;

  /// [chat] opened from the chat list (`CoachChatsPresenter
  /// .onChatPressed`): a chat from before day chats about what it was
  /// about, or [fallback]'s kind when it was saved without one; a day chat
  /// about [fallback], as today's chat is.
  factory forChat(CoachChat chat, CoachContext fallback) => CoachRequest(
    context: chat.day != null
        ? fallback
        : CoachContext(
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
/// There is one chat a day, its id the day's key: the coach opens on
/// today's, followed live, and any other chat is read-only.
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
  }) : _doc = _request.chat?.messages ?? const [],
       super(
         _opened(
           _request.chat,
           localDayKey(_now()),
         ).copyWith(remainingToday: _coach.remainingToday(_uid)),
       );

  /// [chat], or today's ([today]) when there is none or it is today's.
  static CoachState _opened(CoachChat? chat, String today) {
    final live = chat == null || chat.day == today;
    return CoachState(
      messages: chat?.messages ?? const [],
      chatId: live ? today : chat.id,
      day: live ? today : chat.day,
      chatTitle: chat?.title,
      readOnly: !live,
    );
  }

  final String _uid;
  final CoachRequest _request;
  final CoachRepository _coach;
  final PurchasesRepository _purchases;
  final AnalyticsRepository _analytics;
  final DateTime Function() _now;
  final String Function() _newId;
  StreamSubscription<CoachChat?>? _chat;

  /// The chat's messages as last read.
  List<CoachMessage> _doc;

  /// [_doc] as shown: held while a question is answered, as the function
  /// saves the exchange just before it answers, and both would show.
  late List<CoachMessage> _shown = _doc;

  /// This session's turns, until the saved chat has them.
  final _session = <CoachMessage>[];

  /// Messages not shown: an answer being regenerated, until the chat drops
  /// it.
  final _hidden = <String>{};

  /// The chat on screen: what is saved ([_shown]), then this session's turns
  /// it does not have yet. An answer is saved with its question under ids of
  /// the function's own, so once the chat has the answer, it and the
  /// question before it leave the session's.
  List<CoachMessage> get _messages {
    final saved = {for (final message in _shown) message.id};
    final unsaved = <CoachMessage>[];
    for (final message in _session) {
      if (_hidden.contains(message.id)) continue;
      if (!saved.contains(message.id)) {
        unsaved.add(message);
      } else if (unsaved.lastOrNull?.role == CoachMessageRole.user) {
        unsaved.removeLast();
      }
    }
    return [
      for (final message in _shown)
        if (!_hidden.contains(message.id)) message,
      ...unsaved,
    ];
  }

  Map<String, Object?> get _contextParameter => {
    'context': _request.context.kind.value,
  };

  /// `CoachView_Appear`, then the gate, read once (`onViewAppear`): only
  /// this screen moves it after that, so a refusal from the function can
  /// move it back. Today's chat is followed from here on.
  Future<void> appeared() async {
    _analytics.appear('CoachView', _contextParameter);
    if (!state.readOnly) _chat ??= _follow(state.chatId!);
    if (!_purchases.state.isPremiumWith()) {
      emit(state.copyWith(gate: CoachGate.premium));
      return;
    }
    final consented = await _coach.watchConsent(_uid).first;
    if (isClosed) return;
    emit(state.copyWith(gate: consented ? CoachGate.chat : CoachGate.consent));
  }

  StreamSubscription<CoachChat?> _follow(String chatId) =>
      _coach.watchChat(_uid, chatId).listen((chat) {
        _doc = chat?.messages ?? const [];
        if (_answering != null) return;
        _shown = _doc;
        emit(state.copyWith(messages: _messages));
      }, onError: (Object _) {});

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
    if (text.isEmpty || !state.canSend) return;
    emit(state.copyWith(draft: '', draftRevision: state.draftRevision + 1));
    await _ask(text);
  }

  /// Retry under a failed or stopped question: asks it again, as the
  /// newest message.
  Future<void> retryPressed(String questionId) async {
    final question = _session
        .where((message) => message.id == questionId)
        .firstOrNull;
    if (question == null || state.isSending) return;
    _analytics.analytic('CoachView_Retry_Press', _contextParameter);
    _session.remove(question);
    emit(
      state.copyWith(
        messages: _messages,
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
    final answer = state.messages.last.id;
    _replaced = answer;
    _hidden.add(answer);
    emit(state.copyWith(messages: _messages));
    await _ask(state.messages.last.text, regenerating: true);
  }

  /// The answer a regeneration hides while the new one streams.
  String? _replaced;

  /// Ends a regeneration that got no new answer: [from], with the question
  /// no longer pending, then the answer it hid back in place. False when
  /// nothing is being regenerated.
  ///
  /// In two steps, so the old answer coming back is not announced as a new
  /// one: the view announces an answer that arrives as answering ends.
  bool _restored(CoachState from, String questionId) {
    final replaced = _replaced;
    if (replaced == null) return false;
    _replaced = null;
    emit(from.copyWith(questions: {...from.questions}..remove(questionId)));
    _hidden.remove(replaced);
    emit(state.copyWith(messages: _messages));
    return true;
  }

  /// Stop, while the coach answers: drops what has streamed and leaves the
  /// question marked stopped, with Retry; or for a regeneration, brings the
  /// old answer back. The quota stays spent.
  void stopPressed() {
    final questionId = _answering;
    if (questionId == null) return;
    _analytics.analytic('CoachView_Stop_Press', _contextParameter);
    _endAnswer();
    final stopped = state.copyWith(
      messages: _messages,
      questions: {
        ...state.questions,
        questionId: const CoachQuestionStatus.stopped(),
      },
      streamingText: () => null,
      streamingBlocks: const [],
    );
    if (!_restored(stopped, questionId)) emit(stopped);
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

  /// Asks [text] in the chat on screen. The question shows at once and the
  /// answer streams in after it. On a failure the question stays, marked
  /// failed, to retry; a refusal for consent or premium takes it off, puts
  /// it back in the field and goes back to that gate instead.
  ///
  /// [regenerating] asks the last message, already shown, again.
  Future<void> _ask(String text, {bool regenerating = false}) {
    final isNewChat = _shown.isEmpty;
    final question = regenerating
        ? state.messages.last
        : CoachMessage(
            id: _newId(),
            role: CoachMessageRole.user,
            text: text,
            createdAt: _now(),
          );
    if (!regenerating) _session.add(question);
    _answering = question.id;
    emit(
      state.copyWith(
        questions: {
          ...state.questions,
          question.id: const CoachQuestionStatus.answering(),
        },
        streamingText: () => '',
        streamingBlocks: const [],
        messages: _messages,
        hasAsked: true,
        newDayStarted: false,
      ),
    );
    _analytics.analytic('CoachView_Send_Start', {
      ..._contextParameter,
      'is_new_chat': isNewChat,
    });
    final answered = _answered = Completer<void>();
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
            emit(state.copyWith(messages: _messages));
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
      case CoachFinished(:final messageId, :final text):
        // The old answer stays hidden until the chat drops it.
        _replaced = null;
        _session.add(
          CoachMessage(
            id: messageId,
            role: CoachMessageRole.assistant,
            text: text,
            createdAt: _now(),
            blocks: event.blocks.isEmpty ? null : event.blocks,
          ),
        );
        emit(
          state.copyWith(
            remainingToday: event.remainingToday,
            questions: {...state.questions}..remove(_answering),
            streamingText: () => null,
            streamingBlocks: const [],
            messages: _messages,
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
    _endAnswer();
    if (failure == CoachFailure.pastDay) return _newDay(question.text);
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
      question.id,
    );
    if (restored) return;
    if (gate != null) _session.remove(question);
    emit(
      gate == null
          ? common.copyWith(
              messages: _messages,
              questions: {
                ...state.questions,
                question.id: CoachQuestionStatus.failed(failure),
              },
            )
          // The gate's way: the question goes back in the field.
          : common.copyWith(
              gate: gate,
              questions: {...state.questions}..remove(question.id),
              messages: _messages,
              draft: question.text,
              draftRevision: state.draftRevision + 1,
            ),
    );
  }

  /// The chat's day ended while it was open (the function refused it as a
  /// past day): moves to today's chat, with [question] back in the field,
  /// and says so.
  void _newDay(String question) {
    final today = localDayKey(_now());
    unawaited(_chat?.cancel());
    _session.clear();
    _hidden.clear();
    _replaced = null;
    _doc = _shown = const [];
    emit(
      state.copyWith(
        chatId: () => today,
        day: () => today,
        chatTitle: () => null,
        messages: const [],
        questions: const {},
        streamingText: () => null,
        streamingBlocks: const [],
        draft: question,
        draftRevision: state.draftRevision + 1,
        newDayStarted: true,
      ),
    );
    _chat = _follow(today);
  }

  /// Lets go of the answer: the stream is cancelled (not awaited, as a
  /// generator only stops at its next chunk), the chat as last read is
  /// shown, and [_ask]'s future completes.
  void _endAnswer() {
    unawaited(_answer?.cancel());
    _answer = null;
    _answering = null;
    _shown = _doc;
    if (_answered case final answered? when !answered.isCompleted) {
      answered.complete();
    }
  }

  /// Chats from the toolbar; the view opens the list.
  void chatsPressed() => _analytics.analytic('CoachView_Chats_Press');

  @override
  Future<void> close() async {
    _endAnswer();
    await _chat?.cancel();
    await super.close();
  }
}
