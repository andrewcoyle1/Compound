import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/inbox/inbox_bloc.dart';
import 'package:compound/nutrition/view/widgets/meal_draft_bar.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:compound/workout_tracker/view/start_workout.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The tab bar around the five tabs, each keeping its own navigation stack.
class AppShell extends StatelessWidget {
  const new({required this.navigationShell, super.key});

  /// go_router's shell: the current tab and its stack.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final badge = context.select<InboxBloc, int>(
      (bloc) => bloc.state.tabBadgeCount,
    );
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AppTabBar(
        accessory: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The workout under way, while its tracker is minimised.
            ActiveWorkoutBar(),
            // The unlogged meal, when no workout is under way.
            MealDraftBar(),
          ],
        ),
        selectedIndex: navigationShell.currentIndex,
        // Tapping the current tab again returns it to its root, as on iOS.
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: [
          for (final tab in AppTab.values)
            AppTabBarItem(
              icon: tab.icon,
              selectedIcon: tab.selectedIcon,
              label: tab.label(l10n),
              // The comments and mentions unread and the follow requests
              // waiting (`TabBarPresenter.unreadActivityCount`).
              badgeCount: tab == AppTab.social ? badge : 0,
            ),
        ],
      ),
    );
  }
}
