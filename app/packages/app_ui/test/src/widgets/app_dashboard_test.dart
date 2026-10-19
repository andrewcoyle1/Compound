import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppDashboard', () {
    const sections = [
      AppSection(
        header: 'One',
        children: [AppListRow(title: 'a')],
      ),
      AppSection(
        header: 'Two',
        children: [AppListRow(title: 'b')],
      ),
      AppSection(
        header: 'Three',
        children: [AppListRow(title: 'c')],
      ),
    ];

    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(const AppDashboard(sections: sections));
    }

    testWidgets('is one column on a phone', (tester) async {
      await pumpAt(tester, const Size(390, 844));
      expect(find.byType(ListView), findsOneWidget);
      final one = tester.getTopLeft(find.text('One'));
      final two = tester.getTopLeft(find.text('Two'));
      expect(two.dx, one.dx);
      expect(two.dy, greaterThan(one.dy));
    });

    testWidgets('alternates two columns on an iPad', (tester) async {
      await pumpAt(tester, const Size(1024, 1366));
      expect(find.byType(ListView), findsNothing);
      final one = tester.getTopLeft(find.text('One'));
      final two = tester.getTopLeft(find.text('Two'));
      final three = tester.getTopLeft(find.text('Three'));
      expect(two.dy, one.dy);
      expect(two.dx, greaterThan(one.dx));
      expect(three.dx, one.dx);
      expect(three.dy, greaterThan(one.dy));
    });
  });

  group('AppDashboard golden', () {
    const sections = [
      AppSection(
        header: 'Training',
        children: [
          AppListRow(
            title: 'Upper A',
            subtitle: 'Week 2 of 5',
            accessory: AppListRowChevron(),
          ),
        ],
      ),
      AppSection(
        header: 'Nutrition',
        children: [
          AppListRow(title: 'Calories', accessory: AppListRowValue('1,850')),
        ],
      ),
      AppSection(
        header: 'Body',
        children: [
          AppListRow(title: 'Weight', accessory: AppListRowValue('81.4 kg')),
        ],
      ),
    ];
    goldenStates(
      'app_dashboard',
      [('Phone: one column', const AppDashboard(sections: sections))],
      height: 420,
      padded: false,
    );
    goldenStates(
      'app_dashboard_wide',
      [('Wide: two columns', const AppDashboard(sections: sections))],
      width: AppContentWidth.twoColumns,
      height: 300,
      padded: false,
    );
  });
}
