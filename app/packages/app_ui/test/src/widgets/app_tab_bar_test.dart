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
}
