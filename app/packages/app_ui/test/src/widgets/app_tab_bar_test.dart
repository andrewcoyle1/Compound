import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

const _items = [
  AppTabBarItem(
    icon: AppSymbols.today,
    selectedIcon: AppSymbols.todayFilled,
    label: 'Today',
  ),
  AppTabBarItem(
    icon: AppSymbols.friends,
    selectedIcon: AppSymbols.friendsFilled,
    label: 'Social',
    badgeCount: 3,
  ),
];

void main() {
  group('AppTabBar', () {
    testWidgets('fills the selected glyph and outlines the rest', (
      tester,
    ) async {
      final tapped = <int>[];
      await tester.pumpApp(
        AppTabBar(items: _items, selectedIndex: 0, onSelected: tapped.add),
      );
      expect(find.byIcon(AppSymbols.todayFilled), findsOneWidget);
      expect(find.byIcon(AppSymbols.friends), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.text('Social'));
      expect(tapped, [1]);
    });

    testWidgets('announces which tab is selected', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        AppTabBar(items: _items, selectedIndex: 1, onSelected: (_) {}),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Social'))),
        isSemantics(isSelected: true),
      );
      handle.dispose();
    });

    testWidgets('grows only to 1.3 times at large text', (tester) async {
      await tester.pumpApp(
        AppTabBar(items: _items, selectedIndex: 0, onSelected: (_) {}),
        textScale: 3,
      );
      expect(
        tester.getSize(find.byType(NavigationBar)).height,
        AppTabBar.height * AppTabBar.maxTextScale,
      );
    });
  });

  group('AppTabBar dock', () {
    Future<void> pumpDock(
      WidgetTester tester, {
      Widget? accessory,
      EdgeInsets padding = EdgeInsets.zero,
    }) => tester.pumpApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: padding),
          child: Scaffold(
            bottomNavigationBar: AppTabBar(
              items: _items,
              selectedIndex: 0,
              onSelected: (_) {},
              accessory: accessory,
            ),
          ),
        ),
      ),
      scaffold: false,
    );

    Rect card(WidgetTester tester) => tester.getRect(
      find.ancestor(
        of: find.byType(NavigationBar),
        matching: find.byType(AppCard),
      ),
    );

    testWidgets('insets the tabs as a card on the canvas', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpDock(tester);
      final screen = tester.getSize(find.byType(Scaffold));
      final rect = card(tester);
      expect(rect.left, AppSpacing.l);
      expect(rect.right, screen.width - AppSpacing.l);
      expect(rect.bottom, screen.height - AppSpacing.s);
      expect(
        tester.getSize(find.byType(AppTabBar)).height,
        AppSpacing.s + AppTabBar.height + AppSpacing.s,
      );
      // No hairline along the top any more.
      expect(
        find.descendant(
          of: find.byType(AppTabBar),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).border != null,
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('clears the home indicator once, not twice', (tester) async {
      await pumpDock(tester, padding: const EdgeInsets.only(bottom: 34));
      final screen = tester.getSize(find.byType(Scaffold));
      expect(card(tester).bottom, screen.height - 34);
      expect(
        tester.getSize(find.byType(NavigationBar)).height,
        AppTabBar.height,
      );
    });

    testWidgets('holds to the readable width on a wide screen', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpDock(tester);
      expect(card(tester).width, AppContentWidth.readable - 2 * AppSpacing.l);
      expect(card(tester).center.dx, 600);
    });

    testWidgets('shows an accessory above the tabs', (tester) async {
      await pumpDock(tester, accessory: const Text('Accessory'));
      expect(
        tester.getBottomLeft(find.text('Accessory')).dy,
        lessThanOrEqualTo(card(tester).top),
      );
    });
  });

  group('AppTabBar golden', () {
    const items = [
      AppTabBarItem(
        icon: AppSymbols.today,
        selectedIcon: AppSymbols.todayFilled,
        label: 'Today',
      ),
      AppTabBarItem(
        icon: AppSymbols.workout,
        selectedIcon: AppSymbols.workoutFilled,
        label: 'Training',
      ),
      AppTabBarItem(
        icon: AppSymbols.nutrition,
        selectedIcon: AppSymbols.nutritionFilled,
        label: 'Nutrition',
      ),
      AppTabBarItem(
        icon: AppSymbols.analytics,
        selectedIcon: AppSymbols.analyticsFilled,
        label: 'Progress',
      ),
      AppTabBarItem(
        icon: AppSymbols.friends,
        selectedIcon: AppSymbols.friendsFilled,
        label: 'Social',
        badgeCount: 3,
      ),
    ];
    goldenStates(
      'app_tab_bar',
      [
        (
          'First selected, a badge',
          AppTabBar(items: items, selectedIndex: 0, onSelected: (_) {}),
        ),
        (
          'Middle selected',
          AppTabBar(items: items, selectedIndex: 2, onSelected: (_) {}),
        ),
        (
          'Long labels',
          AppTabBar(
            items: [
              for (final (i, label) in [
                'Hoy',
                'Entrenamiento',
                'Nutrición',
                'Progreso',
                'Social',
              ].indexed)
                AppTabBarItem(
                  icon: items[i].icon,
                  selectedIcon: items[i].selectedIcon,
                  label: label,
                ),
            ],
            selectedIndex: 1,
            onSelected: (_) {},
          ),
        ),
        (
          'An accessory above',
          AppTabBar(
            items: items,
            selectedIndex: 1,
            onSelected: (_) {},
            accessory: AppTabAccessory(
              semanticLabel: 'Resume Push Day',
              onTap: () {},
              child: const Text('Push Day'),
            ),
          ),
        ),
      ],
      width: 375,
      padded: false,
    );
  });
}
