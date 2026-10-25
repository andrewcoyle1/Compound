import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/onboarding/logic/onboarding_step.dart';
import 'package:compound/onboarding/view/onboarding_widgets.dart';
import 'package:compound/paywall/cubit/subscribe_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// "Why Subscribe?" (Swift's onboarding Subscription step): what the
/// subscription includes, Continue to the plans, and the way out for
/// someone who will not subscribe: their account, deleting it, and signing
/// out. The router holds a user here until they are premium
/// (`AppAuthenticated.needsSubscription`).
class SubscribePage extends StatelessWidget {
  const new({super.key});

  static const path = '/subscribe';
  static const name = 'subscribe';

  /// The paywall, pushed as part of onboarding.
  static const plansPath = 'plans';
  static const plansName = 'subscribePlans';

  /// Edit Profile, below this screen.
  static const accountPath = 'account';
  static const accountName = 'subscribeAccount';

  /// Delete Account, below this screen.
  static const deleteAccountPath = 'delete-account';
  static const deleteAccountName = 'subscribeDeleteAccount';

  /// The Legal screen, below the plans.
  static const legalName = 'subscribeLegal';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SubscribeCubit(
        auth: context.read<AuthRepository>(),
        analytics: context.read<AnalyticsRepository>(),
      )..appeared(),
      child: const SubscribeView(),
    );
  }
}

class SubscribeView extends StatefulWidget {
  const new({super.key});

  @override
  State<SubscribeView> createState() => _SubscribeViewState();
}

class _SubscribeViewState extends State<SubscribeView> {
  late final SubscribeCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<SubscribeCubit>();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<SubscribeCubit, int>(
      listener: (context, _) => showAppSnackBar(
        context,
        l10n.settingsSignOutFailed,
        style: AppSnackBarStyle.error,
      ),
      child: OnboardingQuestion(
        step: OnboardingStep.subscription,
        title: l10n.subscribeTitle,
        subtitle: l10n.subscribeSubtitle,
        onContinue: () {
          _cubit.continuePressed();
          unawaited(context.pushNamed<void>(SubscribePage.plansName));
        },
        secondaryLabel: l10n.signOutButton,
        onSecondary: () => unawaited(_cubit.signOutPressed()),
        children: [
          AppSection(children: subscriptionFeatureRows(context)),
          AppSection(
            footer: l10n.subscribeAccountFooter,
            children: [
              AppListRowButton(
                title: l10n.paywallAccount,
                icon: AppSymbols.profile,
                onPressed: () {
                  _cubit.accountPressed();
                  unawaited(context.pushNamed<void>(SubscribePage.accountName));
                },
              ),
              AppListRowButton(
                title: l10n.settingsDeleteAccount,
                icon: AppSymbols.delete,
                onPressed: () => unawaited(
                  context.pushNamed<void>(SubscribePage.deleteAccountName),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What the subscription includes (Swift `SubscriptionFeatureRows`), listed
/// once for Subscription and the paywall.
List<Widget> subscriptionFeatureRows(BuildContext context) {
  final l10n = context.l10n;
  final isApple = switch (Theme.of(context).platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };
  return [
    AppFeatureRow(
      icon: AppSymbols.mesocycle,
      title: l10n.subscriptionFeaturePlans,
      detail: l10n.subscriptionFeaturePlansDetail,
    ),
    AppFeatureRow(
      icon: AppSymbols.knowledgeBase,
      title: l10n.subscriptionFeatureCoaching,
      detail: l10n.subscriptionFeatureCoachingDetail,
    ),
    AppFeatureRow(
      icon: AppSymbols.analytics,
      title: l10n.subscriptionFeatureProgress,
      detail: l10n.subscriptionFeatureProgressDetail,
    ),
    AppFeatureRow(
      icon: AppSymbols.heart,
      title: isApple
          ? l10n.subscriptionFeatureHealthApple
          : l10n.subscriptionFeatureHealthAndroid,
      detail: isApple
          ? l10n.subscriptionFeatureHealthAppleDetail
          : l10n.subscriptionFeatureHealthAndroidDetail,
    ),
    AppFeatureRow(
      icon: AppSymbols.notifications,
      title: l10n.subscriptionFeatureAccountability,
      detail: l10n.subscriptionFeatureAccountabilityDetail,
    ),
  ];
}
