import 'package:app_ui/app_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// [item] inside a menu, as a menu item's semantics require.
Widget _inMenu(Widget item) =>
    Semantics(role: SemanticsRole.menu, explicitChildNodes: true, child: item);

void main() {
  group('AppMenuItem', () {
    testWidgets('returns its value when chosen from the menu', (tester) async {
      String? chosen;
      await tester.pumpApp(
        PopupMenuButton<String>(
          tooltip: 'Options',
          onSelected: (value) => chosen = value,
          itemBuilder: (_) => [
            AppMenuItem(label: 'Notes', value: 'notes', icon: AppSymbols.note),
            AppMenuItem(
              label: 'Delete',
              value: 'delete',
              icon: AppSymbols.delete,
              isDestructive: true,
            ),
          ],
        ),
      );
      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();
      expect(find.byIcon(AppSymbols.note), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(chosen, 'delete');
    });

    testWidgets('draws a destructive item in danger', (tester) async {
      await tester.pumpApp(
        _inMenu(
          AppMenuItem(
            label: 'Discard',
            value: 0,
            icon: AppSymbols.delete,
            isDestructive: true,
          ),
        ),
      );
      final danger = AppColors.light.danger;
      expect(tester.widget<Icon>(find.byIcon(AppSymbols.delete)).color, danger);
      expect(tester.widget<Text>(find.text('Discard')).style?.color, danger);
    });

    testWidgets('has no icon unless given one', (tester) async {
      await tester.pumpApp(_inMenu(AppMenuItem(label: 'Pause', value: 0)));
      expect(find.byType(Icon), findsNothing);
      expect(find.text('Pause'), findsOneWidget);
    });
  });

  group('AppMenuItem golden', () {
    goldenStates('app_menu_item', [
      (
        'Icon',
        _inMenu(
          AppMenuItem(label: 'Workout Notes…', value: 0, icon: AppSymbols.note),
        ),
      ),
      ('Text only', _inMenu(AppMenuItem(label: 'Pause Workout', value: 0))),
      (
        'Destructive',
        _inMenu(
          AppMenuItem(
            label: 'Discard Workout',
            value: 0,
            icon: AppSymbols.delete,
            isDestructive: true,
          ),
        ),
      ),
    ], width: 260);
  });
}
