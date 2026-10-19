import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void _goldenTap() {}

void main() {
  group('AppListRowButton', () {
    testWidgets('the whole row is one button with a chevron', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        AppListRowButton(
          title: 'Units',
          subtitle: 'Metric',
          icon: AppSymbols.settings,
          onPressed: () => taps++,
        ),
      );
      expect(find.byIcon(AppSymbols.disclosure), findsOneWidget);
      await tester.tap(find.text('Metric'));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byType(AppListRowButton)),
        isSemantics(label: 'Units\nMetric', isButton: true, hasTapAction: true),
      );
    });

    testWidgets('passes a thumbnail to the row', (tester) async {
      await tester.pumpApp(
        AppListRowButton(
          title: 'Oats',
          thumbnail: const ColoredBox(
            key: Key('thumbnail'),
            color: Color(0xFF000000),
          ),
          onPressed: () {},
        ),
      );
      expect(find.byKey(const Key('thumbnail')), findsOneWidget);
    });

    testWidgets('takes another accessory', (tester) async {
      await tester.pumpApp(
        const AppListRowButton(
          title: 'Weight',
          onPressed: null,
          accessory: AppListRowValue('82.5 kg'),
        ),
      );
      expect(find.byIcon(AppSymbols.disclosure), findsNothing);
      expect(find.text('82.5 kg'), findsOneWidget);
    });

    testWidgets('a destructive row is drawn in the danger colour', (
      tester,
    ) async {
      await tester.pumpApp(
        AppListRowButton(
          title: 'Delete Account',
          icon: AppSymbols.delete,
          accessory: null,
          destructive: true,
          onPressed: () {},
        ),
      );
      final title = tester.widget<Text>(find.text('Delete Account'));
      expect(title.style?.color, AppColors.light.danger);
      final icon = tester.widget<Icon>(find.byIcon(AppSymbols.delete));
      expect(icon.color, AppColors.light.danger);
    });
  });

  group('AppListRowButton golden', () {
    Widget card(Widget row) => AppCard(child: row);
    goldenStates('app_list_row_button', [
      (
        'Icon and chevron',
        card(
          const AppListRowButton(
            title: 'Notifications',
            icon: AppSymbols.notifications,
            onPressed: _goldenTap,
          ),
        ),
      ),
      (
        'Subtitle',
        card(
          const AppListRowButton(
            title: 'Apple Health',
            subtitle: 'Connected',
            icon: AppSymbols.integrations,
            onPressed: _goldenTap,
          ),
        ),
      ),
      (
        'Destructive',
        card(
          const AppListRowButton(
            title: 'Sign Out',
            onPressed: _goldenTap,
            accessory: null,
            destructive: true,
          ),
        ),
      ),
      (
        'Disabled',
        card(
          const AppListRowButton(
            title: 'Export Data',
            icon: AppSymbols.openExternally,
            onPressed: null,
          ),
        ),
      ),
    ]);
  });
}
