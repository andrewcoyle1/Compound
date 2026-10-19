import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppSection', () {
    testWidgets('puts rows on a card with dividers between', (tester) async {
      await tester.pumpApp(
        const AppSection(
          header: 'Goal',
          footer: 'Change it any time.',
          children: [
            AppListRow(title: 'One'),
            AppListRow(title: 'Two'),
            AppListRow(title: 'Three'),
          ],
        ),
      );
      expect(find.byType(AppCard), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.text('Change it any time.'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Goal')),
        isSemantics(label: 'Goal', isHeader: true),
      );
    });

    testWidgets('starts each divider at the text of the row above', (
      tester,
    ) async {
      await tester.pumpApp(
        AppSection(
          children: [
            const Text('Note'),
            const AppListRow(title: 'Icon', icon: AppSymbols.goal),
            const AppListRowButton(
              title: 'Thumbnail',
              thumbnail: SizedBox(),
              onPressed: null,
            ),
            const AppListRowToggle(
              title: 'Toggle',
              value: false,
              onChanged: null,
            ),
            AppListRowToggle(
              title: 'Toggle with icon',
              icon: AppSymbols.notifications,
              value: false,
              onChanged: (_) {},
            ),
            const AppListRow(title: 'Last'),
          ],
        ),
      );
      final indents = tester
          .widgetList<Divider>(find.byType(Divider))
          .map((divider) => divider.indent);
      const icon = AppSpacing.l + AppControlSize.icon + AppSpacing.m;
      expect(indents, [
        AppSpacing.l,
        icon,
        AppSpacing.l + AppControlSize.thumbnail + AppSpacing.m,
        AppSpacing.l,
        icon,
      ]);
    });

    testWidgets('ungrouped children stand apart, without a shared card', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppSection(
          header: 'Feed',
          grouped: false,
          children: [
            AppCard(child: Text('One')),
            AppCard(child: Text('Two')),
          ],
        ),
      );
      expect(find.byType(AppCard), findsNWidgets(2));
      expect(find.byType(Divider), findsNothing);
      expect(
        tester.getTopLeft(find.text('Two')).dy -
            tester.getBottomLeft(find.text('One')).dy,
        AppSpacing.m,
      );
    });

    testWidgets('header and footer are optional', (tester) async {
      await tester.pumpApp(
        const AppSection(children: [AppListRow(title: 'One')]),
      );
      expect(find.byType(Divider), findsNothing);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('a trailing note or action sits beside the header', (
      tester,
    ) async {
      var hidden = false;
      await tester.pumpApp(
        Column(
          children: [
            const AppSection(
              header: 'Exercise Name',
              trailing: Text('Required'),
              children: [AppListRow(title: 'One')],
            ),
            AppSection(
              trailing: AppChip(label: 'Hide', onPressed: () => hidden = true),
              children: const [AppListRow(title: 'Two')],
            ),
          ],
        ),
      );
      final note = tester.widget<RichText>(
        find.descendant(
          of: find.text('Required'),
          matching: find.byType(RichText),
        ),
      );
      expect(note.text.style?.fontSize, AppTextStyles.label.fontSize);
      expect(
        tester.getCenter(find.text('Required')).dy,
        closeTo(tester.getCenter(find.text('Exercise Name')).dy, 1),
      );
      await tester.tap(find.text('Hide'));
      expect(hidden, isTrue);
    });
  });

  group('AppSection golden', () {
    goldenStates('app_section', [
      (
        'Header, rows and footer',
        const AppSection(
          header: 'Rest',
          footer: 'Applies to new workouts.',
          children: [
            AppListRow(
              title: 'Compound lifts',
              accessory: AppListRowValue('3:00'),
            ),
            AppListRow(title: 'Isolation', accessory: AppListRowValue('1:30')),
          ],
        ),
      ),
      (
        'Icon rows indent the divider',
        const AppSection(
          header: 'Integrations',
          children: [
            AppListRow(title: 'Apple Health', icon: AppSymbols.integrations),
            AppListRow(title: 'Strava', icon: AppSymbols.sync),
          ],
        ),
      ),
      (
        'Trailing action',
        AppSection(
          header: 'Workouts',
          trailing: AppChip(label: 'See All', onPressed: () {}),
          children: const [AppListRow(title: 'Upper A')],
        ),
      ),
      (
        'Ungrouped cards',
        AppSection(
          header: 'Workout Feed',
          trailing: AppChip(label: 'Find People', onPressed: () {}),
          grouped: false,
          children: const [
            AppCard(child: AppListRow(title: 'Push Day')),
            AppCard(child: AppListRow(title: 'Pull Day')),
          ],
        ),
      ),
      (
        'Trailing note',
        const AppSection(
          header: 'Name',
          trailing: Text('Required'),
          children: [AppListRow(title: 'Push Day')],
        ),
      ),
    ]);
  });
}
