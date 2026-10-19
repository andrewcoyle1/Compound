import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  final scheme = AppTheme.light.colorScheme;
  const longSubtitle =
      'A long subtitle that explains the option in more words than two lines '
      'can hold on a phone, so a capped row would cut it short.';

  group('AppListRow', () {
    testWidgets('shows title and subtitle, at least 52 pt tall', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppListRow(title: 'Units', subtitle: 'Metric'),
      );
      expect(find.text('Units'), findsOneWidget);
      expect(find.text('Metric'), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppListRow)).height,
        greaterThanOrEqualTo(AppControlSize.listRow),
      );
    });

    testWidgets('caps the subtitle at two lines', (tester) async {
      await tester.pumpApp(
        const AppListRow(title: 'Title', subtitle: longSubtitle),
      );
      expect(tester.widget<Text>(find.text(longSubtitle)).maxLines, 2);
    });

    testWidgets('never caps a checkmark row', (tester) async {
      await tester.pumpApp(
        const AppListRow(
          title: 'Title',
          subtitle: longSubtitle,
          accessory: AppListRowCheckmark(selected: false),
        ),
      );
      expect(tester.widget<Text>(find.text(longSubtitle)).maxLines, isNull);
    });

    testWidgets('leads with an icon in the accent or tint', (tester) async {
      await tester.pumpApp(
        const Column(
          children: [
            AppListRow(title: 'A', icon: AppSymbols.settings),
            AppListRow(
              title: 'B',
              icon: AppSymbols.steps,
              tint: Color(0xFF00C7BE),
            ),
          ],
        ),
      );
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons[0].color, scheme.primary);
      expect(icons[1].color, const Color(0xFF00C7BE));
      expect(icons[0].size, AppControlSize.icon);
    });

    testWidgets('leads with a clipped thumbnail', (tester) async {
      await tester.pumpApp(
        const AppListRow(
          title: 'Squat',
          thumbnail: ColoredBox(color: Color(0xFF000000)),
        ),
      );
      expect(find.byType(ClipRSuperellipse), findsOneWidget);
      expect(
        tester.getSize(find.byType(ColoredBox).last),
        const Size.square(AppControlSize.thumbnail),
      );
    });

    testWidgets('a chevron is a tertiary glyph', (tester) async {
      await tester.pumpApp(
        const AppListRow(title: 'Open', accessory: AppListRowChevron()),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, AppSymbols.disclosure);
      expect(icon.color, scheme.outline);
    });

    testWidgets('a selected checkmark is announced as selected', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppListRow(
          title: 'Kilograms',
          accessory: AppListRowCheckmark(selected: true),
        ),
      );
      expect(
        tester.widget<Icon>(find.byType(Icon)).icon,
        AppSymbols.choiceSelected,
      );
      expect(
        tester.getSemantics(find.byType(AppListRow)),
        matchesSemantics(
          label: 'Kilograms',
          isSelected: true,
          hasSelectedState: true,
        ),
      );
    });

    testWidgets('an unselected checkmark is an empty circle', (tester) async {
      await tester.pumpApp(
        const AppListRow(
          title: 'Pounds',
          accessory: AppListRowCheckmark(selected: false),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, AppSymbols.choiceUnselected);
      expect(icon.color, scheme.outline);
    });

    testWidgets('a value trails the title', (tester) async {
      await tester.pumpApp(
        const AppListRow(
          title: 'Weight',
          accessory: AppListRowValue('82.5 kg'),
        ),
      );
      final value = find.text('82.5 kg');
      expect(tester.widget<Text>(value).textAlign, TextAlign.end);
      expect(
        tester.getTopLeft(value).dx,
        greaterThan(tester.getTopRight(find.text('Weight')).dx),
      );
    });

    testWidgets('at accessibility sizes a value moves under the title', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppListRow(
          title: 'Weight',
          subtitle: longSubtitle,
          accessory: AppListRowValue('82.5 kg'),
        ),
        textScale: 2,
      );
      final value = find.text('82.5 kg');
      expect(tester.widget<Text>(value).textAlign, TextAlign.start);
      expect(tester.widget<Text>(find.text(longSubtitle)).maxLines, isNull);
      expect(
        tester.getTopLeft(value).dy,
        greaterThan(tester.getBottomLeft(find.text('Weight')).dy),
      );
    });

    testWidgets('a custom accessory stays its own element', (tester) async {
      await tester.pumpApp(
        AppListRow(
          title: 'Notes',
          accessory: AppListRowCustom(
            TextButton(onPressed: () {}, child: const Text('Edit')),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Edit'), findsOneWidget);
      expect(find.bySemanticsLabel('Notes'), findsOneWidget);
    });

    testWidgets('a menu shows its value with an up-and-down chevron', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppListRow(title: 'Type', accessory: AppListRowMenu('None')),
      );
      expect(find.text('None'), findsOneWidget);
      expect(find.byIcon(AppSymbols.choose), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('None')).dx,
        greaterThan(tester.getTopLeft(find.text('Type')).dx),
      );
    });
  });

  group('AppListRow golden', () {
    Widget card(Widget row) => AppCard(child: row);
    goldenStates('app_list_row', [
      ('Title', card(const AppListRow(title: 'Units'))),
      (
        'Subtitle and chevron',
        card(
          const AppListRow(
            title: 'Barbell Bench Press',
            subtitle: 'Chest · Triceps · Shoulders',
            accessory: AppListRowChevron(),
          ),
        ),
      ),
      (
        'Icon and value',
        card(
          const AppListRow(
            title: 'Body weight',
            icon: AppSymbols.scaleWeight,
            accessory: AppListRowValue('81.4 kg'),
          ),
        ),
      ),
      (
        'Tinted icon and menu',
        Builder(
          builder: (context) => card(
            AppListRow(
              title: 'Protein target',
              icon: AppSymbols.protein,
              tint: context.appColors.protein,
              accessory: const AppListRowMenu('High'),
            ),
          ),
        ),
      ),
      (
        'Thumbnail',
        Builder(
          builder: (context) => card(
            AppListRow(
              title: 'Overnight oats',
              subtitle: '420 kcal',
              thumbnail: ColoredBox(color: context.appColors.carbs),
              accessory: const AppListRowChevron(),
            ),
          ),
        ),
      ),
      (
        'Checkmark',
        card(
          const AppListRow(
            title: 'Kilograms',
            accessory: AppListRowCheckmark(selected: true),
          ),
        ),
      ),
      (
        'Destructive',
        card(
          const AppListRow(
            title: 'Delete Account',
            icon: AppSymbols.delete,
            destructive: true,
          ),
        ),
      ),
      (
        'Long title',
        card(
          const AppListRow(
            title: 'Single-arm dumbbell row with a pause at the top',
            subtitle: 'Back · Biceps',
            accessory: AppListRowValue('3 × 10'),
          ),
        ),
      ),
    ]);
  });
}
