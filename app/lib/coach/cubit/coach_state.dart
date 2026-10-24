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
  /// Being answered.
  const new answering() : phase = CoachQuestionPhase.answering, failure = null;

  /// Got no answer, for [failure].
  const new failed(CoachFailure this.failure)
    : phase = CoachQuestionPhase.failed;

  /// Stopped by the user.
  const new stopped() : phase = CoachQuestionPhase.stopped, failure = null;

  final CoachQuestionPhase phase;

  /// Why a failed question got no answer.
  final CoachFailure? failure;

  @override
  List<Object?> get props => [phase, failure];
}

/// The coach screen (Swift `CoachPresenter`'s state).
final class const CoachState({
  final CoachGate gate = CoachGate.loading,

  /// The conversation on screen: the stored chat when one was opened, then
  /// this session's turns. Every message is drawn by one widget
  /// (`CoachMessageBody`), so structured content can be added to the model
  /// later without touching the rest.
  final List<CoachMessage> messages = const [],

  /// How many of [messages] came from the stored chat: their blocks are
  /// snapshots, shown with the day they were read.
  final int savedMessageCount = 0,

  /// The answer as it streams in; null when nothing is streaming.
  final String? streamingText,

  /// The blocks the streaming answer has shown so far, in order.
  final List<CoachBlock> streamingBlocks = const [],

  /// The chat being continued; null until the first answer of a new one.
  final String? chatId,

  /// The saved chat's title, once there is one.
  final String? chatTitle,

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

  bool get canSend => !isSending && draft.trim().isNotEmpty;

  CoachState copyWith({
    CoachGate? gate,
    List<CoachMessage>? messages,
    int? savedMessageCount,
    String? Function()? streamingText,
    List<CoachBlock>? streamingBlocks,
    String? Function()? chatId,
    String? Function()? chatTitle,
    Map<String, CoachQuestionStatus>? questions,
    bool? isGivingConsent,
    String? draft,
    int? draftRevision,
    int? remainingToday,
    int? sendFailures,
    int? consentFailures,
  }) => CoachState(
    gate: gate ?? this.gate,
    messages: messages ?? this.messages,
    savedMessageCount: savedMessageCount ?? this.savedMessageCount,
    streamingText: streamingText == null ? this.streamingText : streamingText(),
    streamingBlocks: streamingBlocks ?? this.streamingBlocks,
    chatId: chatId == null ? this.chatId : chatId(),
    chatTitle: chatTitle == null ? this.chatTitle : chatTitle(),
    questions: questions ?? this.questions,
    isGivingConsent: isGivingConsent ?? this.isGivingConsent,
    draft: draft ?? this.draft,
    draftRevision: draftRevision ?? this.draftRevision,
    remainingToday: remainingToday ?? this.remainingToday,
    sendFailures: sendFailures ?? this.sendFailures,
    consentFailures: consentFailures ?? this.consentFailures,
  );

  @override
  List<Object?> get props => [
    gate,
    messages,
    savedMessageCount,
    streamingText,
    streamingBlocks,
    chatId,
    chatTitle,
    questions,
    isGivingConsent,
    draft,
    draftRevision,
    remainingToday,
    sendFailures,
    consentFailures,
  ];
}
