import 'dart:async';

import 'package:ab_test_repository/ab_test_repository.dart';
import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/ab_tests_cubit.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/paywall/cubit/paywall_cubit.dart';
import 'package:compound/paywall/view/subscribe_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart' as rc;

/// The paywall (Swift `PaywallView`): the plans, Subscribe, Restore, the
/// renewal terms and the legal links, in the paywall test's variant
/// ([paywallVariant]).
///
/// Off onboarding ([isOnboarding] false) it is a full-screen dialog with a
/// close button, and a purchase closes it with `true`. During onboarding
/// it is pushed from Subscription, offers the account and signing out, and
/// the router moves on once the user is premium.
class PaywallPage extends StatelessWidget {
  const new({required this.isOnboarding, super.key});

  /// Over the tabs, from the coach and Settings.
  static const path = '/paywall';
  static const name = 'paywall';

  /// Below [path] and Subscription's plans: the Legal screen.
  static const legalPath = 'legal';
  static const legalName = 'paywallLegal';

  final bool isOnboarding;

  /// The variant this user sees: the paywall test's arm, except that
  /// RevenueCat's paywall needs RevenueCat running, so without it (the
  /// premium fake, or no key) the user sees `custom`.
  static PaywallTestOption paywallVariant(
    PaywallTestOption test,
    PurchasesRepository purchases,
  ) => switch ((test, purchases)) {
    (
      PaywallTestOption.revenueCat,
      RevenueCatPurchasesRepository(isConfigured: true),
    ) =>
      PaywallTestOption.revenueCat,
    (PaywallTestOption.revenueCat, _) => PaywallTestOption.custom,
    _ => test,
  };

  @override
  Widget build(BuildContext context) {
    final purchases = context.read<PurchasesRepository>();
    return BlocProvider(
      create: (context) => PaywallCubit(
        purchases: purchases,
        variant: paywallVariant(
          context.read<AbTestsCubit>().state.paywallTest,
          purchases,
        ),
        auth: context.read<AuthRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        // The `.dev.` products everywhere but production, as Swift's DEBUG.
        productIds: SubscriptionPlan.productIds(
          development: appFlavor != 'production',
        ),
      )..appeared(),
      child: PaywallView(isOnboarding: isOnboarding),
    );
  }
}

class PaywallView extends StatefulWidget {
  const new({required this.isOnboarding, super.key});

  final bool isOnboarding;

  @override
  State<PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends State<PaywallView> {
  late final PaywallCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<PaywallCubit>();
    // RevenueCat's paywall loads its own products.
    if (_cubit.state.variant != PaywallTestOption.revenueCat) {
      unawaited(_cubit.loadProducts());
    }
  }

  @override
  void dispose() {
    _cubit.disappeared();
    super.dispose();
  }

  void _openLegal() => unawaited(
    context.pushNamed<void>(
      widget.isOnboarding ? SubscribePage.legalName : PaywallPage.legalName,
    ),
  );

  void _onNotice(BuildContext context, PaywallState state) {
    final l10n = context.l10n;
    final isApple = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    final notice = state.notice;
    if (notice == null) return;
    if (notice != PaywallNotice.nothingToRestore) {
      unawaited(HapticFeedback.errorNotification());
    }
    final (title, message) = switch (notice) {
      PaywallNotice.purchaseFailed => (
        l10n.paywallPurchaseFailed,
        l10n.paywallLoadFailedMessage,
      ),
      PaywallNotice.restoreFailed => (
        l10n.paywallRestoreFailed,
        l10n.paywallLoadFailedMessage,
      ),
      PaywallNotice.nothingToRestore => (
        l10n.paywallNothingToRestore,
        isApple
            ? l10n.paywallNothingToRestoreApple
            : l10n.paywallNothingToRestoreGoogle,
      ),
      PaywallNotice.signOutFailed => (
        l10n.settingsSignOutFailed,
        l10n.paywallLoadFailedMessage,
      ),
    };
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.settingsOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<PaywallCubit>().state;
    return MultiBlocListener(
      listeners: [
        BlocListener<PaywallCubit, PaywallState>(
          listenWhen: (previous, current) =>
              current.noticeId != previous.noticeId,
          listener: _onNotice,
        ),
        BlocListener<PaywallCubit, PaywallState>(
          listenWhen: (previous, current) =>
              current.isComplete && !previous.isComplete,
          listener: (context, _) {
            unawaited(HapticFeedback.successNotification());
            // During onboarding the router moves on by itself.
            if (!widget.isOnboarding) context.pop(true);
          },
        ),
      ],
      child: AppScaffold(
        appBar: AppBar(
          leading: widget.isOnboarding
              ? null
              : CloseButton(
                  onPressed: () {
                    _cubit.closePressed();
                    context.pop();
                  },
                ),
          actions: [
            if (widget.isOnboarding)
              PopupMenuButton<bool>(
                icon: const Icon(AppSymbols.profile),
                tooltip: l10n.paywallAccount,
                onSelected: (signOut) {
                  if (signOut) {
                    unawaited(_cubit.signOutPressed());
                  } else {
                    _cubit.accountPressed();
                    unawaited(
                      context.pushNamed<void>(SubscribePage.accountName),
                    );
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: false, child: Text(l10n.paywallAccount)),
                  PopupMenuItem(value: true, child: Text(l10n.signOutButton)),
                ],
              ),
          ],
        ),
        bottomNavigationBar:
            state.load == PaywallLoad.loaded &&
                _cubit.state.variant != PaywallTestOption.revenueCat
            ? _PurchaseBar(state: state, onLegalPressed: _openLegal)
            : null,
        body: switch (state.load) {
          _ when _cubit.state.variant == PaywallTestOption.revenueCat =>
            const _RevenueCatPaywall(),
          PaywallLoad.loading => const Center(
            child: CircularProgressIndicator.adaptive(),
          ),
          PaywallLoad.failed || PaywallLoad.empty => _LoadFailed(
            message: state.load == PaywallLoad.empty
                ? l10n.paywallNoProducts
                : l10n.paywallLoadFailedMessage,
          ),
          PaywallLoad.loaded
              when _cubit.state.variant == PaywallTestOption.storeKit =>
            _StorePlans(state: state),
          PaywallLoad.loaded => _Plans(state: state),
        },
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const new({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.m,
          children: [
            Icon(
              AppSymbols.error,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            Text(
              l10n.paywallLoadFailedTitle,
              style: AppTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
            Text(
              message,
              style: AppTextStyles.rowDetail,
              textAlign: TextAlign.center,
            ),
            AppCtaButton(
              label: l10n.tryAgainButton,
              onPressed: () =>
                  unawaited(context.read<PaywallCubit>().loadProducts()),
            ),
          ],
        ),
      ),
    );
  }
}

/// "£4.99 / 1 month": the price with the billing period, as Swift's
/// `localizedPriceWithPeriod`.
String priceWithPeriod(AppLocalizations l10n, SubscriptionProduct product) {
  final period = switch (product.duration) {
    ProductDuration.year => l10n.paywallPeriodYear,
    ProductDuration.month => l10n.paywallPeriodMonth,
    ProductDuration.week => l10n.paywallPeriodWeek,
    ProductDuration.day => l10n.paywallPeriodDay,
    null => null,
  };
  return period == null
      ? product.priceString
      : l10n.paywallPricePeriod(product.priceString, period);
}

class _Plans extends StatelessWidget {
  const new({required this.state});

  final PaywallState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PaywallCubit>();
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: [
        // One product name everywhere, and no trial wording: there is no
        // trial.
        Text(
          l10n.paywallTitle,
          style: AppTextStyles.display.copyWith(color: colors.primary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          l10n.paywallSubtitle,
          style: AppTextStyles.rowDetail,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        // The plans first, so the price and the choice need no scrolling.
        AppSection(
          children: [
            for (final product in state.products)
              AppSelectableRow(
                title: product.title,
                subtitle:
                    '${priceWithPeriod(l10n, product)}\n${product.subtitle}',
                selected: product == state.selected,
                onPressed: () {
                  unawaited(HapticFeedback.selectionClick());
                  cubit.productSelected(product);
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        AppSection(
          header: l10n.paywallIncluded,
          children: subscriptionFeatureRows(context),
        ),
      ],
    );
  }
}

/// The `storeKit` variant. Swift shows StoreKit's own subscription screen,
/// which Flutter has no free equivalent for (and Google Play none at all),
/// so this draws its layout: the name and a line on the accent, then the
/// plans to pick from, with Subscribe, Restore and the policies below.
class _StorePlans extends StatelessWidget {
  const new({required this.state});

  final PaywallState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PaywallCubit>();
    final colors = Theme.of(context).colorScheme;
    return ListView(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.primary, colors.primary.withValues(alpha: 0.7)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              spacing: AppSpacing.s,
              children: [
                Text(
                  l10n.paywallTitle,
                  style: AppTextStyles.display.copyWith(
                    color: colors.onPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  l10n.paywallSubtitle,
                  style: AppTextStyles.rowDetail.copyWith(
                    color: colors.onPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: AppSection(
            children: [
              for (final product in state.products)
                AppSelectableRow(
                  title: product.title,
                  subtitle: priceWithPeriod(l10n, product),
                  selected: product == state.selected,
                  onPressed: () {
                    unawaited(HapticFeedback.selectionClick());
                    cubit.productSelected(product);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The `revenueCat` variant: RevenueCat's paywall, designed in its
/// dashboard, which buys and restores by itself. It never closes itself;
/// the page's own close button and the cubit decide where a purchase lands,
/// as Swift's `onRequestedDismissal` does.
class _RevenueCatPaywall extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PaywallCubit>();
    return rc.PaywallView(
      displayCloseButton: false,
      onPurchaseCompleted: (info, _) => cubit.revenueCatPurchaseCompleted(
        hasActiveEntitlement: info.entitlements.active.isNotEmpty,
      ),
      onRestoreCompleted: (info) => cubit.revenueCatRestoreCompleted(
        hasActiveEntitlement: info.entitlements.active.isNotEmpty,
      ),
      onDismiss: () {},
    );
  }
}

class _PurchaseBar extends StatelessWidget {
  const new({required this.state, required this.onLegalPressed});

  final PaywallState state;
  final VoidCallback onLegalPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<PaywallCubit>();
    final selected = state.selected;
    return AppBottomCta(
      children: [
        // Always in view, as Swift's top inset is.
        if (state.isPending)
          AppInlineMessage(
            kind: AppInlineMessageKind.info,
            text: l10n.paywallPending,
            kindLabel: l10n.infoLabel,
          ),
        if (selected != null)
          Text(
            l10n.paywallRenews(priceWithPeriod(l10n, selected)),
            style: AppTextStyles.label.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        AppCtaButton(
          label: l10n.paywallSubscribe,
          onPressed: selected == null
              ? null
              : () => unawaited(cubit.subscribePressed()),
        ),
        AppCtaButton(
          label: l10n.paywallRestore,
          variant: AppCtaVariant.plain,
          onPressed: () => unawaited(cubit.restorePressed()),
        ),
        // The purchase page links the terms and the privacy policy. Swift's
        // addresses are placeholders, so both open the Legal screen.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.l,
          children: [
            TextButton(
              onPressed: onLegalPressed,
              child: Text(l10n.legalTermsOfService),
            ),
            TextButton(
              onPressed: onLegalPressed,
              child: Text(l10n.legalPrivacyPolicy),
            ),
          ],
        ),
      ],
    );
  }
}
