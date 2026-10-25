import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:checkin_repository/checkin_repository.dart' show localMidnight;
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/coach/cubit/coach_cubit.dart';
import 'package:compound/coach/view/coach_chats_page.dart';
import 'package:compound/coach/view/coach_conversation.dart';
import 'package:compound/coach/view/coach_day_card.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/paywall/view/paywall_page.dart';
import 'package:compound/today/today.dart';
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
          create: (context) => TodayPage.createBloc(
            context,
            state.user.uid,
            tracksAppear: false,
          ),
        ),
      ],
      child: CoachView(request: request, opener: const CoachDayCard()),
    );
  }
}

class CoachView extends StatefulWidget {
  const new({required this.request, this.opener, super.key});

  final CoachRequest request;

  /// The day's checklist, at the top of today's chat.
  final Widget? opener;

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
              previous.isGivingConsent && current.gate == CoachGate.chat,
          listener: (context, _) {
            unawaited(AppHaptics.success());
            if (widget.request.closesOnConsent) context.pop();
          },
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
          CoachGate.chat => CoachConversation(
            request: widget.request,
            draft: _draft,
            opener: widget.opener,
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
            color: context.appColors.accentInk,
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
          style: AppTextStyles.rowDetail.secondary(context),
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
