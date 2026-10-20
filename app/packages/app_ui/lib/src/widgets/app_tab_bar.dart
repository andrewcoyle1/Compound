import 'package:app_ui/app_ui.dart';

/// One tab of an [AppTabBar].
class AppTabBarItem {
  /// A tab.
  const new({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  /// The outlined glyph, shown while the tab is not selected.
  final IconData icon;

  /// The filled glyph, shown while the tab is selected.
  final IconData selectedIcon;

  /// The tab's title, localized.
  final String label;

  /// A count badged on the glyph, such as unread activity. None at zero.
  final int badgeCount;
}

/// {@template app_tab_bar}
/// The app's tab bar: a dock on the canvas along the bottom edge, holding the
/// tabs in a card like the content's ([AppCardStyle.card]), inset by the
/// screen gutter, held to the readable width and clear of the home
/// indicator. An [accessory] (an [AppTabAccessory]) sits above the tabs as a
/// matching card. The dock is opaque: content is laid out above it, never
/// behind it.
///
/// The selected tab is marked by its filled glyph and the accent on a tinted
/// capsule, the others are outlined in secondary grey, with no ink splash
/// (set in `AppTheme`'s `navigationBarTheme`).
///
/// Labels grow with the text only up to [maxTextScale] times, as iOS's tab
/// bar does not grow with it, so five tabs keep fitting at the largest sizes.
/// Screen readers announce each tab and which one is selected.
/// {@endtemplate}
class AppTabBar extends StatelessWidget {
  /// {@macro app_tab_bar}
  const new({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.accessory,
    super.key,
  });

  /// The tabs, in order.
  final List<AppTabBarItem> items;

  /// The selected tab's index in [items].
  final int selectedIndex;

  /// Called with a tab's index when it is tapped, the selected one included.
  final ValueChanged<int> onSelected;

  /// Bars above the tabs, usually [AppTabAccessory]s, which hide themselves
  /// when there is nothing to show.
  final Widget? accessory;

  /// The largest text scale the labels follow: Material's `NavigationBar`
  /// limit.
  static const maxTextScale = 1.3;

  /// The tab card's height at the default text size.
  static const height = 56.0;

  @override
  Widget build(BuildContext context) {
    final accessory = this.accessory;
    // NavigationBar holds its labels to 1.3 times, as iOS's tab bar does
    // not grow with the text, so five tabs keep fitting; the bar grows only
    // that far with them.
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: maxTextScale);
    // Snack bars sit above the dock.
    return AppSnackBarClearance(
      child: ColoredBox(
        color: context.appColors.canvas,
        child: AppReadableWidth(
          // The SafeArea takes the home indicator's inset off what it passes
          // down, so NavigationBar does not leave room for it a second time.
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: AppSpacing.s),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?accessory,
                  AppCard(
                    // The badge's count too, which NavigationBar leaves to
                    // grow until it covers the tab's icon.
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: maxTextScale,
                      child: NavigationBar(
                        height: scaler.scale(height),
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysShow,
                        selectedIndex: selectedIndex,
                        onDestinationSelected: onSelected,
                        destinations: [
                          for (final item in items)
                            NavigationDestination(
                              icon: _badged(item, item.icon),
                              selectedIcon: _badged(item, item.selectedIcon),
                              label: item.label,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _badged(AppTabBarItem item, IconData icon) => Badge.count(
    count: item.badgeCount,
    isLabelVisible: item.badgeCount > 0,
    child: Icon(icon),
  );
}
