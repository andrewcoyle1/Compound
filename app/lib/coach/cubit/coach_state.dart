part of 'coach_cubit.dart';

/// What the coach screen shows (Swift `CoachPresenter.Gate`, plus the
/// moment before consent has been read). Premium is checked first, then
/// consent, so nothing reaches the provider before both.
enum CoachGate {
  /// Reading whether the user has agreed yet.
  loading,

  /// Not a subscriber: the coach is part of Premium.
  premium,

  /// No agreement to share data with the provider yet.
  consent,

  /// The chat.
  chat,
}

/// Where a question without an answer stands.
enum CoachQuestionPhase {
  /// The coach is answering it.
  answering,

  /// No answer came; it can be retried.
  failed,

  /// The user stopped the answer; it can be retried.
  stopped,
}

/// A question the coach has not answered: one per question, so each
/// failed or stopped question keeps its own note and Retry. Answered
/// questions have none.
final class CoachQuestionStatus extends Equatable {
  /// Being answered, while the coach runs [tool], if it said.
  const new answering([this.tool])
    : phase = CoachQuestionPhase.answering,
      failure = null;

  /// Got no answer, for [failure].
  const new failed(CoachFailure this.failure)
    : phase = CoachQuestionPhase.failed,
      tool = null;

  /// Stopped by the user.
  const new stopped()
    : phase = CoachQuestionPhase.stopped,
      failure = null,
      tool = null;

  final CoachQuestionPhase phase;

  /// Why a failed question got no answer.
  final CoachFailure? failure;

  /// The tool the coach is running for the answer ([CoachStatus]), such as
  /// `get_nutrition` or `show_block`; null once the answer moves on to text
  /// or a block, or before it says.
  final String? tool;

  @override
  List<Object?> get props => [phase, failure, tool];
}

/// The coach screen (Swift `CoachPresenter`'s state).
final class const CoachState({
  final CoachGate gate = CoachGate.loading,

  /// The conversation on screen: the chat as saved, then this session's
  /// turns not saved yet. Every message is drawn by one widget
  /// (`CoachMessageBody`), so structured content can be added to the model
  /// later without touching the rest.
  final List<CoachMessage> messages = const [],

  /// The answer as it streams in; null when nothing is streaming.
  final String? streamingText,

  /// The blocks the streaming answer has shown so far, in order.
  final List<CoachBlock> streamingBlocks = const [],

  /// The chat on screen: today's is the day's key, `YYYY-MM-DD`.
  final String? chatId,

  /// The day the chat belongs to; null for a chat from before day chats.
  final String? day,

  /// The saved chat's title.
  final String? chatTitle,

  /// A past day's chat, or one from before day chats: it can be read, not
  /// added to, and its blocks are snapshots, shown with the day they were
  /// read.
  final bool readOnly = false,

  /// Whether a question has been asked on this screen: until then, a
  /// question about the screen it was opened from is offered.
  final bool hasAsked = false,

  /// The day ended while the chat was open: the screen moved to the new
  /// day's chat, with the question back in the field, and says so.
  final bool newDayStarted = false,

  /// The questions without an answer, by message id: the one being
  /// answered, and any that failed or were stopped.
  final Map<String, CoachQuestionStatus> questions = const {},
  final bool isGivingConsent = false,

  /// The message field.
  final String draft = '',

  /// Bumped whenever the cubit, not the user, sets [draft] (sending clears
  /// it, a failure puts the message back), so the field follows.
  final int draftRevision = 0,

  /// What is left of today's messages after the last answer.
  final int? remainingToday,

  /// Counts failed sends, for the error haptic and the Retry note.
  final int sendFailures = 0,

  /// Counts failed consent saves, for the alert.
  final int consentFailures = 0,

  /// Counts failed regenerations, for the notice: the old answer stays.
  final int regenerateFailures = 0,
}) extends Equatable {
  /// The questions offered before the first message.
  bool get showsSuggestions => messages.isEmpty && streamingText == null;

  /// The few messages left, so the limit is not a surprise; null when
  /// there are more than ten or none is known.
  int? get remainingShown => switch (remainingToday) {
    final remaining? when remaining <= 10 => remaining,
    _ => null,
  };

  /// Whether the coach is answering a question.
  bool get isSending => questions.values.any(
    (status) => status.phase == CoachQuestionPhase.answering,
  );

  bool get canSend => !readOnly && !isSending && draft.trim().isNotEmpty;

  /// The tool the coach is running for the question it is answering.
  String? get reading => questions.values
      .where((status) => status.phase == CoachQuestionPhase.answering)
      .firstOrNull
      ?.tool;

  /// Whether the last message is an answer to the question before it, in a
  /// saved chat, so it can be asked for again.
  bool get canRegenerate =>
      !readOnly &&
      !isSending &&
      messages.length >= 2 &&
      messages.last.role == CoachMessageRole.assistant &&
      messages[messages.length - 2].role == CoachMessageRole.user;

  CoachState copyWith({
    CoachGate? gate,
    List<CoachMessage>? messages,
    String? Function()? streamingText,
    List<CoachBlock>? streamingBlocks,
    String? Function()? chatId,
    String? Function()? day,
    String? Function()? chatTitle,
    bool? readOnly,
    bool? hasAsked,
    bool? newDayStarted,
    Map<String, CoachQuestionStatus>? questions,
    bool? isGivingConsent,
    String? draft,
    int? draftRevision,
    int? remainingToday,
    int? sendFailures,
    int? consentFailures,
    int? regenerateFailures,
  }) => CoachState(
    gate: gate ?? this.gate,
    messages: messages ?? this.messages,
    streamingText: streamingText == null ? this.streamingText : streamingText(),
    streamingBlocks: streamingBlocks ?? this.streamingBlocks,
    chatId: chatId == null ? this.chatId : chatId(),
    day: day == null ? this.day : day(),
    chatTitle: chatTitle == null ? this.chatTitle : chatTitle(),
    readOnly: readOnly ?? this.readOnly,
    hasAsked: hasAsked ?? this.hasAsked,
    newDayStarted: newDayStarted ?? this.newDayStarted,
    questions: questions ?? this.questions,
    isGivingConsent: isGivingConsent ?? this.isGivingConsent,
    draft: draft ?? this.draft,
    draftRevision: draftRevision ?? this.draftRevision,
    remainingToday: remainingToday ?? this.remainingToday,
    sendFailures: sendFailures ?? this.sendFailures,
    consentFailures: consentFailures ?? this.consentFailures,
    regenerateFailures: regenerateFailures ?? this.regenerateFailures,
  );

  @override
  List<Object?> get props => [
    gate,
    messages,
    streamingText,
    streamingBlocks,
    chatId,
    day,
    chatTitle,
    readOnly,
    hasAsked,
    newDayStarted,
    questions,
    isGivingConsent,
    draft,
    draftRevision,
    remainingToday,
    sendFailures,
    consentFailures,
    regenerateFailures,
  ];
}
