import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/coach/cubit/coach_cubit.dart';
import 'package:compound/coach/view/coach_chats_page.dart';
import 'package:compound/coach/view/coach_message_body.dart';
import 'package:compound/coach/view/coach_text.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/paywall/view/paywall_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_repository/purchases_repository.dart';

/// The AI coach (Swift `CoachView`). Every Ask Coach button opens this with
/// the context it was asked from; it checks premium, then consent, itself,
/// so every way in behaves the same.
class CoachPage extends StatelessWidget {
  const new({this.request = const CoachRequest(), super.key});

  /// Over the tabs, from anywhere.
  static const path = '/coach';

  /// The route name.
  static const name = 'coach';

  /// Opens the coach about [coachContext] over the current screen, as
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
    return BlocProvider(
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
      child: CoachView(request: request),
    );
  }
}

class CoachView extends StatefulWidget {
  const new({required this.request, super.key});

  final CoachRequest request;

  @override
  State<CoachView> createState() => _CoachViewState();
}

class _CoachViewState extends State<CoachView> {
  late final CoachCubit _cubit;
  final _draft = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _cubit = context.read<CoachCubit>();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CoachCubit>().state;
    final title = state.gate == CoachGate.chat
        ? state.chatTitle ?? widget.request.context.title ?? l10n.coachTitle
        : l10n.coachTitle;
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
              current.messages.length != previous.messages.length ||
              current.streamingText != previous.streamingText,
          listener: (_, _) => _scrollToEnd(),
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
            if (state.gate == CoachGate.chat)
              PopupMenuButton<void Function()>(
                icon: Icon(AppSymbols.more),
                tooltip: l10n.coachMore,
                onSelected: (action) => action(),
                itemBuilder: (context) => [
                  AppMenuItem(
                    value: _cubit.newChatPressed,
                    icon: AppSymbols.add,
                    label: l10n.coachNewChat,
                  ),
                  AppMenuItem(
                    value: () {
                      _cubit.chatsPressed();
                      unawaited(
                        context.pushNamed<void>(
                          CoachChatsPage.name,
                          extra: widget.request.context,
                        ),
                      );
                    },
                    icon: AppSymbols.history,
                    label: l10n.coachChats,
                  ),
                ],
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
            scroll: _scroll,
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

class _Chat extends StatelessWidget {
  const new({required this.request, required this.draft, required this.scroll});

  final CoachRequest request;
  final TextEditingController draft;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CoachCubit>();
    final state = context.watch<CoachCubit>().state;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final streaming = state.streamingText;
    final failure = state.failure;
    final remaining = state.remainingShown;
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              if (state.showsSuggestions) ...[
                Text(
                  l10n.coachEmptyMessage,
                  style: AppTextStyles.rowDetail.copyWith(color: secondary),
                ),
                const SizedBox(height: AppSpacing.m),
                AppSection(
                  children: [
                    for (final question in l10n.coachSuggestions(
                      request.context.kind,
                    ))
                      AppListRowButton(
                        icon: AppSymbols.coach,
                        title: question,
                        accessory: null,
                        onPressed: () =>
                            unawaited(cubit.suggestionPressed(question)),
                      ),
                  ],
                ),
              ],
              for (final message in state.messages)
                Padding(
                  key: ValueKey(message.id),
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: CoachMessageBody(
                    role: message.role,
                    text: message.text,
                  ),
                ),
              if (streaming != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.m),
                  child: streaming.isEmpty
                      ? const Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.m),
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        )
                      : CoachMessageBody(
                          role: CoachMessageRole.assistant,
                          text: streaming,
                        ),
                ),
              if (failure != null)
                AppInlineMessage(
                  kind: AppInlineMessageKind.warning,
                  text: l10n.coachFailure(failure),
                  kindLabel: l10n.coachTitle,
                ),
            ],
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
              children: [
                if (remaining != null)
                  Text(
                    l10n.coachMessagesLeft(remaining),
                    style: AppTextStyles.label.copyWith(color: secondary),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: AppSpacing.s,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('Coach.draft'),
                        controller: draft,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        onChanged: cubit.draftChanged,
                        onSubmitted: (_) => unawaited(cubit.sendPressed()),
                        decoration: InputDecoration(
                          hintText: l10n.coachInputHint,
                          filled: true,
                          fillColor: context.appColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.l),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    AppIconButton(
                      icon: AppSymbols.send,
                      semanticLabel: l10n.coachSend,
                      onPressed: state.canSend
                          ? () => unawaited(cubit.sendPressed())
                          : null,
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
    );
  }
}
