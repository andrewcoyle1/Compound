import 'dart:async';
import 'dart:math' as math;

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:checkin_repository/checkin_repository.dart' show localMidnight;
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/coach/cubit/coach_cubit.dart';
import 'package:compound/coach/view/coach_chats_page.dart';
import 'package:compound/coach/view/coach_day_card.dart';
import 'package:compound/coach/view/coach_message_body.dart';
import 'package:compound/coach/view/coach_text.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/paywall/view/paywall_page.dart';
import 'package:compound/today/today.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_repository/purchases_repository.dart';

/// The AI coach (Swift `CoachView`): today's chat, opening on the day's
/// checklist, or a past day's, read-only. Every Ask Coach button opens
/// today's chat with the context it was asked from; it checks premium, then
/// consent, itself, so every way in behaves the same.
class CoachPage extends StatelessWidget {
  const new({this.request = const CoachRequest(), super.key});

  /// Over the tabs, from anywhere.
  static const path = '/coach';

  /// The route name.
  static const name = 'coach';

  /// Opens today's chat about [coachContext] over the current screen, as
  /// Swift's `AskCoachRouter.showCoach`.
  static void open(BuildContext context, CoachContext coachContext) =>
      unawaited(
        context.pushNamed<void>(
          name,
          extra: CoachRequest(context: coachContext),
        ),
      );

  final CoachRequest request;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final cubit = CoachCubit(
              uid: state.user.uid,
              request: request,
              coach: context.read<CoachRepository>(),
              purchases: context.read<PurchasesRepository>(),
              analytics: context.read<AnalyticsRepository>(),
            );
            unawaited(cubit.appeared());
            return cubit;
          },
        ),
        // The day's checklist, read only when today's chat shows it.
        BlocProvider(
          create: (context) => TodayPage.createBloc(context, state.user.uid),
        ),
      ],
      child: CoachView(request: request, dayCard: const CoachDayCard()),
    );
  }
}

class CoachView extends StatefulWidget {
  const new({required this.request, this.dayCard, super.key});

  final CoachRequest request;

  /// The day's checklist, at the top of today's chat.
  final Widget? dayCard;

  @override
  State<CoachView> createState() => _CoachViewState();
}

class _CoachViewState extends State<CoachView> {
  late final CoachCubit _cubit;
  final _draft = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cubit = context.read<CoachCubit>();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CoachCubit>().state;
    final title = switch (state) {
      CoachState(gate: CoachGate.chat, readOnly: true, :final day?) =>
        AppFormat.date(
          localMidnight(day),
          style: AppDateStyle.weekdayMedium,
          locale: context.dateLocale,
        ),
      CoachState(gate: CoachGate.chat, readOnly: true, :final chatTitle?) =>
        chatTitle,
      _ => l10n.coachTitle,
    };
    return MultiBlocListener(
      listeners: [
        BlocListener<CoachCubit, CoachState>(
          listenWhen: (previous, current) =>
              current.draftRevision != previous.draftRevision,
          listener: (_, state) => _draft.text = state.draft,
        ),
        BlocListener<CoachCubit, CoachState>(
          listenWhen: (previous, current) =>
              current.sendFailures != previous.sendFailures,
          listener: (_, _) => unawaited(AppHaptics.error()),
        ),
        BlocListener<CoachCubit, CoachState>(
          listenWhen: (previous, current) =>
              previous.isGivingConsent && current.gate == CoachGate.chat,
          listener: (_, _) => unawaited(AppHaptics.success()),
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
              current.consentFailures != previous.consentFailures,
          listener: (context, _) => unawaited(
            showFailureAlert(
              context,
              l10n.coachConsentFailed,
              l10n.metricTryAgain,
            ),
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
      child: AppScaffold(
        backgroundColor: context.appColors.canvas,
        appBar: AppBar(
          // Opened as a modal, it closes from the leading edge.
          leading: widget.request.showsCloseButton
              ? AppToolbarButton.close(
                  semanticLabel: MaterialLocalizations.of(context)
                      .closeButtonTooltip,
                )
              : null,
          title: Text(title),
          actions: [
            if (state.gate == CoachGate.chat && !state.readOnly)
              AppToolbarButton(
                icon: AppSymbols.history,
                semanticLabel: l10n.coachChats,
                onPressed: () {
                  _cubit.chatsPressed();
                  unawaited(
                    context.pushNamed<void>(
                      CoachChatsPage.name,
                      extra: widget.request.context,
                    ),
                  );
                },
              ),
          ],
        ),
        body: switch (state.gate) {
          CoachGate.loading => AppLoadingView(label: l10n.launchLoading),
          CoachGate.premium => const _PremiumGate(),
          CoachGate.consent => const _ConsentGate(),
          CoachGate.chat => _Chat(
            request: widget.request,
            draft: _draft,
            dayCard: widget.dayCard,
          ),
        },
        bottomNavigationBar: state.gate == CoachGate.consent
            ? AppBottomCta(
                children: [
                  AppCtaButton(
                    label: l10n.coachConsentAllow,
                    isLoading: state.isGivingConsent,
                    onPressed: () => unawaited(_cubit.consentAccepted()),
                  ),
                  AppCtaButton(
                    label: l10n.coachConsentNotNow,
                    variant: AppCtaVariant.plain,
                    onPressed: () {
                      _cubit.consentDeclined();
                      context.pop();
                    },
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _PremiumGate extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppEmptyState(
      icon: AppSymbols.coach,
      title: l10n.coachPremiumTitle,
      description: l10n.coachPremiumMessage,
      actionLabel: l10n.coachSeePlans,
      onAction: () async {
        final cubit = context.read<CoachCubit>()..seePlansPressed();
        // Swift's `showPaywall(isOnboarding: false)`; coming back, the gate
        // is read again, as Swift's `onViewAppear` does.
        await context.pushNamed<bool>(PaywallPage.name);
        await cubit.appeared();
      },
    );
  }
}

/// Apple's guideline 5.1.2(i): say what is shared and with whom, and ask,
/// before any of it is.
class _ConsentGate extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final isApple = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        ExcludeSemantics(
          child: Icon(
            AppSymbols.coach,
            size: AppIconSize.large.of(context),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        Semantics(
          header: true,
          child: Text(l10n.coachConsentTitle, style: AppTextStyles.display),
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          l10n.coachConsentBody,
          style: AppTextStyles.rowDetail.copyWith(color: secondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSection(
          header: l10n.coachConsentReadsHeader,
          children: [
            AppListRow(
              icon: AppSymbols.workout,
              title: l10n.coachConsentReadsWorkouts,
            ),
            AppListRow(
              icon: AppSymbols.meal,
              title: l10n.coachConsentReadsMeals,
            ),
            AppListRow(
              icon: AppSymbols.scaleWeight,
              title: l10n.coachConsentReadsBody,
            ),
            AppListRow(
              icon: AppSymbols.steps,
              title: isApple
                  ? l10n.coachConsentReadsStepsApple
                  : l10n.coachConsentReadsStepsHealthConnect,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSection(
          header: l10n.coachConsentNeverHeader,
          footer: l10n.coachConsentFooter,
          children: [
            AppListRow(
              icon: AppSymbols.camera,
              title: l10n.coachConsentNeverPhotos,
            ),
            AppListRow(
              icon: AppSymbols.friends,
              title: l10n.coachConsentNeverPeople,
            ),
            AppListRow(
              icon: AppSymbols.cardio,
              title: l10n.coachConsentNeverStrava,
            ),
          ],
        ),
      ],
    );
  }
}

class _Chat extends StatefulWidget {
  const new({required this.request, required this.draft, this.dayCard});

  final CoachRequest request;
  final TextEditingController draft;
  final Widget? dayCard;

  @override
  State<_Chat> createState() => _ChatState();
}

/// The conversation and the composer.
///
/// Scrolling: the latest exchange (the last question and what follows it)
/// is at least as tall as the list, so sending brings the question to the
/// top and the answer grows beneath it. The list follows the answer down
/// while the user is at the bottom; once they drag, it leaves them be and
/// offers Jump to Latest until they are back at the bottom.
class _ChatState extends State<_Chat> {
  final _scroll = ScrollController();

  /// Whether the list keeps the newest text in view as it arrives.
  bool _following = true;

  /// Set while the list glides to a question just sent, so that new text
  /// does not cut the glide short.
  bool _gliding = false;

  @override
  void initState() {
    super.initState();
    // A saved chat opens on its latest exchange.
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
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
    if (_following && !_gliding) _jumpToLatest();
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

    /// The questions for where the coach was opened from, under [intro].
    Widget suggestions(String? intro) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.m,
      children: [
        if (intro != null)
          Text(
            intro,
            style: AppTextStyles.rowDetail.copyWith(color: secondary),
          ),
        AppSection(
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
        ),
      ],
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

    return BlocListener<CoachCubit, CoachState>(
      listenWhen: (previous, current) =>
          current.messages.length > previous.messages.length &&
          current.messages.last.role == CoachMessageRole.user,
      listener: (_, _) {
        unawaited(AppHaptics.light());
        unawaited(_toLatest());
      },
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
                          if (!state.readOnly) ?widget.dayCard,
                          // Today's questions, on a day not yet asked about.
                          if (state.showsSuggestions &&
                              !state.readOnly &&
                              coachContext.kind == CoachContextKind.today)
                            suggestions(l10n.coachEmptyMessage),
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
                                    ),
                                ],
                              ),
                            ),
                          // Opened from another screen: its questions, last,
                          // so just above the field, until one is asked.
                          if (!state.readOnly &&
                              !state.hasAsked &&
                              coachContext.kind != CoachContextKind.today)
                            suggestions(null),
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
                        child: _following
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
            child: Padding(
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
                          style: AppTextStyles.label.copyWith(color: secondary),
                          textAlign: TextAlign.center,
                        ),
                        AppCtaButton(
                          label: l10n.coachAskInToday,
                          variant: AppCtaVariant.secondary,
                          // In place of this day: Back goes to the list.
                          onPressed: () => context.pushReplacementNamed(
                            CoachPage.name,
                            extra: CoachRequest(
                              showsCloseButton: widget.request.showsCloseButton,
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
                              child: TextField(
                                key: const Key('Coach.draft'),
                                controller: widget.draft,
                                minLines: 1,
                                maxLines: 5,
                                textInputAction: TextInputAction.send,
                                onChanged: cubit.draftChanged,
                                onSubmitted: (_) => send(),
                                decoration: InputDecoration(
                                  hintText: l10n.coachInputHint,
                                  filled: true,
                                  fillColor: context.appColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.l,
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
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
                        Text(
                          l10n.coachDisclaimer,
                          style: AppTextStyles.label.copyWith(color: secondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
              ),
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
