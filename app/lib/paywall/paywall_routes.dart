import 'package:app_ui/app_ui.dart';
import 'package:compound/paywall/view/paywall_page.dart';
import 'package:compound/paywall/view/subscribe_page.dart';
import 'package:compound/settings/account/view/delete_account_page.dart';
import 'package:compound/settings/account/view/edit_profile_page.dart';
import 'package:compound/settings/general/view/legal_page.dart';
import 'package:go_router/go_router.dart';

/// Subscription and the paywall.
///
/// - `/subscribe`: "Why Subscribe?", where the router holds a signed-in user
///   who is not premium, with the onboarding paywall, Edit Profile, Delete
///   Account and Legal below it, since nothing else is reachable from there.
/// - `/paywall`: the paywall over the tabs, a full-screen dialog (Swift's
///   cover), from the coach and Settings. It pops `true` after a purchase.
final paywallRoutes = <RouteBase>[
  GoRoute(
    path: SubscribePage.path,
    name: SubscribePage.name,
    builder: (_, _) => const SubscribePage(),
    routes: [
      GoRoute(
        path: SubscribePage.plansPath,
        name: SubscribePage.plansName,
        builder: (_, _) => const PaywallPage(isOnboarding: true),
        routes: [
          GoRoute(
            path: PaywallPage.legalPath,
            name: SubscribePage.legalName,
            builder: (_, _) => const LegalPage(),
          ),
        ],
      ),
      GoRoute(
        path: SubscribePage.accountPath,
        name: SubscribePage.accountName,
        builder: (_, _) => const EditProfilePage(),
      ),
      GoRoute(
        path: SubscribePage.deleteAccountPath,
        name: SubscribePage.deleteAccountName,
        builder: (_, _) => const DeleteAccountPage(),
      ),
    ],
  ),
  GoRoute(
    path: PaywallPage.path,
    name: PaywallPage.name,
    pageBuilder: (_, state) => MaterialPage(
      key: state.pageKey,
      fullscreenDialog: true,
      child: const PaywallPage(isOnboarding: false),
    ),
    routes: [
      GoRoute(
        path: PaywallPage.legalPath,
        name: PaywallPage.legalName,
        builder: (_, _) => const LegalPage(),
      ),
    ],
  ),
];
