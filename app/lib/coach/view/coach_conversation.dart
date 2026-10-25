import 'dart:async';
import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/coach/cubit/coach_cubit.dart';
import 'package:compound/coach/view/coach_message_body.dart';
import 'package:compound/coach/view/coach_page.dart';
import 'package:compound/coach/view/coach_text.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// A chat's conversation and its composer, under [opener]: the coach
/// screen's, with the day's checklist on top, and Today's, under the whole
/// day. It shows the [CoachCubit] above it once its gate is open.
///
/// Scrolling: the latest exchange (the last question and what follows it)
/// is at least as tall as the list, so sending brings the question to the
/// top and the answer grows beneath it. The list follows the answer down
/// while the user is at the bottom; once they drag, it leaves them be and
/// offers Jump to Latest until they are back at the bottom.
class CoachConversation extends StatefulWidget {
  const new({
    required this.request,
    required this.draft,
    this.opener,
    this.opensAtLatest = true,
    super.key,
  });

  final CoachRequest request;

  /// The composer's text, kept by the screen, so a question sent back to
  /// the field by a gate is still there when the chat returns.
  final TextEditingController draft;

  /// What today's chat opens with, above the conversation; a past day
  /// leaves it out.
  final Widget? opener;

  /// Whether a saved chat opens on its latest exchange, as the coach does;
  /// Today opens at the top, on the day.
  final bool opensAtLatest;

  @override
  State<CoachConversation> createState() => _CoachConversationState();
}

class _CoachConversationState extends State<CoachConversation> {
  final _scroll = ScrollController();

  /// Whether the list keeps the newest text in view as it arrives: from the
  /// start when it opens on the latest exchange.
  late bool _following = widget.opensAtLatest;

  /// Set while the list glides to a question just sent, so that new text
  /// does not cut the glide short.
  bool _gliding = false;

  @override
  void initState() {
    super.initState();
    // A saved chat opens on its latest exchange.
    if (widget.opensAtLatest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToLatest() {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  /// Glides to the latest exchange once it is laid out; at once under
  /// reduced motion.
  Future<void> _toLatest() async {
    setState(() {
      _following = true;
      _gliding = true;
    });
    final duration = AppMotion.standard.durationOf(context);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (_scroll.hasClients && duration > Duration.zero) {
      await _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: duration,
        curve: AppMotion.standard.curve,
      );
    }
    _gliding = false;
    if (mounted && _following) _jumpToLatest();
  }

  bool _onScroll(ScrollNotification notification) {
    final following = switch (notification) {
      // The user took hold of the list.
      ScrollStartNotification(dragDetails: _?) => false,
      ScrollEndNotification(:final metrics) when !_gliding =>
        metrics.extentAfter <= AppSpacing.xl,
      _ => _following,
    };
    if (following != _following) setState(() => _following = following);
    return false;
  }

  /// The answer grew, or the keyboard came up: keep the newest in view.
  bool _onMetrics(ScrollMetricsNotification notification) {
    final metrics = notification.metrics;
    // A glide aims at the end as it was; when the list comes out shorter
    // (a long opener, laid out again), it would run past the end, so it
    // lands at once instead.
    final overshot = _gliding && metrics.pixels > metrics.maxScrollExtent;
    if ((_following && !_gliding) || overshot) _jumpToLatest();
    return false;
  }

  void _copy(CoachMessage message) {
    context.read<CoachCubit>().copyPressed(message.role);
    unawaited(
      Clipboard.setData(
        ClipboardData(text: AppMarkdownText.plainText(message.text)),
      ),
    );
    showAppSnackBar(
      context,
      context.l10n.coachCopied,
      style: AppSnackBarStyle.success,
    );
  }

  void _rate({required bool helpful}) {
    context.read<CoachCubit>().feedbackGiven(helpful: helpful);
    showAppSnackBar(
      context,
      context.l10n.coachFeedbackThanks,
      style: AppSnackBarStyle.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CoachCubit>();
    final state = context.watch<CoachCubit>().state;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final streaming = state.streamingText;
    final remaining = state.remainingShown;
    final messages = state.messages;
    final latest = messages.lastIndexWhere(
      (message) => message.role == CoachMessageRole.user,
    );
    final coachContext = widget.request.context;
    void followUp(String question) =>
        unawaited(cubit.suggestionPressed(question));
    void send() => unawaited(cubit.sendPressed());

    final isToday = coachContext.kind == CoachContextKind.today;

    /// Today's questions, on a day not yet asked about: chips just above
    /// the field.
    final chips = !state.readOnly && isToday && state.showsSuggestions;

    /// The questions for where the coach was opened from.
    Widget suggestions() => AppSection(
      header: coachContext.title,
      children: [
        for (final question in l10n.coachSuggestions(coachContext.kind))
          AppListRowButton(
            icon: AppSymbols.coach,
            title: question,
            accessory: null,
            onPressed: () => followUp(question),
          ),
      ],
    );

    /// One quiet line under the conversation, rather than in the composer,
    /// so the field keeps its room at large text sizes.
    final footnote = Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Text(
        l10n.coachDisclaimer,
        style: AppTextStyles.label.copyWith(color: secondary),
        textAlign: TextAlign.center,
      ),
    );

    Widget message(int index) {
      final message = messages[index];
      final status = state.questions[message.id];
      final failure = status?.failure;
      return Padding(
        key: ValueKey(message.id),
        padding: const EdgeInsets.only(bottom: AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.xs,
          children: [
            CoachMessageBody(
              role: message.role,
              text: message.text,
              blocks: message.blocks ?? const [],
              saved: state.readOnly,
              onFollowUp: followUp,
              actions: [
                (AppSymbols.copy, l10n.coachCopy, () => _copy(message)),
                if (message.role == CoachMessageRole.assistant) ...[
                  // Only the latest answer can be asked for again.
                  if (index == messages.length - 1 && state.canRegenerate)
                    (
                      AppSymbols.regenerate,
                      l10n.coachRegenerate,
                      () => unawaited(cubit.regeneratePressed()),
                    ),
                  (
                    AppSymbols.helpful,
                    l10n.coachHelpful,
                    () => _rate(helpful: true),
                  ),
                  (
                    AppSymbols.notHelpful,
                    l10n.coachNotHelpful,
                    () => _rate(helpful: false),
                  ),
                ],
              ],
            ),
            if (status != null && status.phase != CoachQuestionPhase.answering)
              Row(
                spacing: AppSpacing.s,
                children: [
                  Expanded(
                    child: AppInlineMessage(
                      kind: AppInlineMessageKind.warning,
                      text: failure == null
                          ? l10n.coachStopped
                          : l10n.coachFailure(failure),
                      kindLabel: l10n.coachTitle,
                    ),
                  ),
                  // Retrying today's last message only fails again.
                  if (failure != CoachFailure.dailyLimitReached)
                    AppTextButton(
                      label: l10n.coachRetry,
                      onPressed: state.isSending
                          ? null
                          : () => unawaited(cubit.retryPressed(message.id)),
                    ),
                ],
              ),
          ],
        ),
      );
    }

    return MultiBlocListener(
      listeners: [
        BlocListener<CoachCubit, CoachState>(
          listenWhen: (previous, current) =>
              current.messages.length > previous.messages.length &&
              current.messages.last.role == CoachMessageRole.user,
          listener: (_, _) {
            unawaited(AppHaptics.light());
            unawaited(_toLatest());
          },
        ),
        BlocListener<CoachCubit, CoachState>(
          listenWhen: (previous, current) =>
              current.sendFailures != previous.sendFailures,
          listener: (_, _) => unawaited(AppHaptics.error()),
        ),
        BlocListener<CoachCubit, CoachState>(
          listenWhen: (previous, current) =>
              current.regenerateFailures != previous.regenerateFailures,
          listener: (context, _) => showAppSnackBar(
            context,
            l10n.coachRegenerateFailed,
            style: AppSnackBarStyle.error,
          ),
        ),
        BlocListener<CoachCubit, CoachState>(
          listenWhen: (previous, current) =>
              previous.isSending &&
              !current.isSending &&
              current.messages.lastOrNull?.role == CoachMessageRole.assistant,
          // The answer, read out once it is whole.
          listener: (context, state) => unawaited(
            SemanticsService.sendAnnouncement(
              View.of(context),
              l10n.coachCoachSaid(
                AppMarkdownText.plainText(state.messages.last.text),
              ),
              Directionality.of(context),
            ),
          ),
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  NotificationListener<ScrollMetricsNotification>(
                    onNotification: _onMetrics,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: ListView(
                        controller: _scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.all(AppSpacing.l),
                        children: [
                          if (!state.readOnly) ?widget.opener,
                          for (
                            var index = 0;
                            index < (latest < 0 ? messages.length : latest);
                            index++
                          )
                            message(index),
                          if (latest >= 0)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: math.max(
                                  0,
                                  constraints.maxHeight - 2 * AppSpacing.l,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (
                                    var index = latest;
                                    index < messages.length;
                                    index++
                                  )
                                    message(index),
                                  if (streaming != null)
                                    _Answering(
                                      text: streaming,
                                      blocks: state.streamingBlocks,
                                      reading: state.reading,
                                      onFollowUp: followUp,
                                    )
                                  else
                                    footnote,
                                ],
                              ),
                            ),
                          // Opened from another screen: its questions, last,
                          // so just above the field, until one is asked.
                          if (!state.readOnly && !state.hasAsked && !isToday)
                            suggestions(),
                          // Nothing asked yet: under what is there.
                          if (latest < 0) footnote,
                        ],
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: AppSpacing.m,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: AppMotion.quick.durationOf(context),
                        // Nothing to jump to before the first question.
                        child: _following || messages.isEmpty
                            ? const SizedBox.shrink()
                            : AppFloatingButton(
                                icon: AppSymbols.jumpToLatest,
                                label: l10n.coachJumpToLatest,
                                onPressed: () => unawaited(_toLatest()),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (chips)
                  SingleChildScrollView(
                    key: const Key('Coach.suggestions'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.l,
                      AppSpacing.s,
                      AppSpacing.l,
                      0,
                    ),
                    child: Row(
                      spacing: AppSpacing.xs,
                      children: [
                        for (final question in l10n.coachSuggestions(
                          coachContext.kind,
                        ))
                          AppChip(
                            label: question,
                            icon: AppSymbols.coach,
                            onPressed: () => followUp(question),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.l,
                    vertical: AppSpacing.s,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.xs,
                    children: state.readOnly
                        ? [
                            Text(
                              l10n.coachDayEnded,
                              style: AppTextStyles.label.copyWith(
                                color: secondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            AppCtaButton(
                              label: l10n.coachAskInToday,
                              variant: AppCtaVariant.secondary,
                              // In place of this day: Back goes to the list.
                              onPressed: () => context.pushReplacementNamed(
                                CoachPage.name,
                                extra: CoachRequest(
                                  showsCloseButton:
                                      widget.request.showsCloseButton,
                                ),
                              ),
                            ),
                          ]
                        : [
                            if (state.newDayStarted)
                              AppInlineMessage(
                                kind: AppInlineMessageKind.info,
                                text: l10n.coachNewDay,
                                kindLabel: l10n.coachTitle,
                              ),
                            if (remaining != null)
                              Text(
                                l10n.coachMessagesLeft(remaining),
                                style: AppTextStyles.label.copyWith(
                                  color: secondary,
                                ),
                              ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              spacing: AppSpacing.s,
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    key: const Key('Coach.draft'),
                                    hint: l10n.coachInputHint,
                                    controller: widget.draft,
                                    textInputAction: TextInputAction.send,
                                    minLines: 1,
                                    maxLines: 5,
                                    onChanged: cubit.draftChanged,
                                    style: AppTextFieldStyle.composer,
                                    onSubmitted: (_) => send(),
                                  ),
                                ),
                                // While the coach answers, Send becomes Stop.
                                if (state.isSending)
                                  AppIconButton(
                                    icon: AppSymbols.stop,
                                    semanticLabel: l10n.coachStop,
                                    onPressed: cubit.stopPressed,
                                  )
                                else
                                  AppIconButton(
                                    icon: AppSymbols.send,
                                    semanticLabel: l10n.coachSend,
                                    onPressed: state.canSend ? send : null,
                                  ),
                              ],
                            ),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The answer as it streams, and under it what the coach is doing: while
/// it runs a data tool, or before any text, a line saying what it reads;
/// while it lays out a block, a placeholder where the block will land. The
/// line goes once text follows the tool (and comes back for the next one),
/// so it never sits between a sentence and the rest of it.
class _Answering extends StatelessWidget {
  const new({
    required this.text,
    required this.blocks,
    required this.reading,
    required this.onFollowUp,
  });

  final String text;
  final List<CoachBlock> blocks;

  /// The tool the coach is running ([CoachState.reading]).
  final String? reading;
  final ValueChanged<String> onFollowUp;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final placesBlock = reading == 'show_block';
    final showsLine = !placesBlock && (reading != null || text.isEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.m,
      children: [
        if (text.isNotEmpty || blocks.isNotEmpty)
          CoachMessageBody(
            role: CoachMessageRole.assistant,
            text: text,
            blocks: blocks,
            streaming: true,
            onFollowUp: onFollowUp,
          ),
        if (placesBlock)
          AppPlaceholder(
            height: MediaQuery.textScalerOf(context)
                .scale(AppChartHeight.compact),
            radius: AppRadius.xl,
            semanticLabel: l10n.coachAddingCard,
          ),
        if (showsLine)
          Semantics(
            liveRegion: true,
            child: AnimatedSwitcher(
              duration: AppMotion.quick.durationOf(context),
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [...previous, ?current],
              ),
              child: Row(
                key: ValueKey(reading),
                spacing: AppSpacing.s,
                children: [
                  const AppSpinner(size: AppSpinnerSize.small),
                  Flexible(
                    child: Text(
                      l10n.coachReading(reading),
                      style: AppTextStyles.rowDetail.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
