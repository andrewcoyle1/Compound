import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppListRowToggle', () {
    testWidgets('tapping the row toggles', (tester) async {
      bool? changed;
      await tester.pumpApp(
        AppListRowToggle(
          title: 'Reminders',
          subtitle: 'Daily',
          icon: AppSymbols.notifications,
          value: false,
          onChanged: (value) => changed = value,
        ),
      );
      await tester.tap(find.text('Reminders'));
      expect(changed, isTrue);
    });

    testWidgets('the switch toggles too and reads with the title', (
      tester,
    ) async {
      bool? changed;
      await tester.pumpApp(
        AppListRowToggle(
          title: 'Reminders',
          value: true,
          onChanged: (value) => changed = value,
        ),
      );
      await tester.tap(find.byType(Switch));
      expect(changed, isFalse);
      // The row is the tap target, so the switch adds no height of its own.
      expect(
        tester.widget<Switch>(find.byType(Switch)).materialTapTargetSize,
        MaterialTapTargetSize.shrinkWrap,
      );
      expect(
        tester.getSize(find.byType(AppListRow)).height,
        AppControlSize.listRow,
      );
      expect(
        tester.getSemantics(find.byType(AppListRowToggle)),
        isSemantics(label: 'Reminders', isToggled: true),
      );
    });

    testWidgets('disabled, the row does nothing', (tester) async {
      await tester.pumpApp(
        const AppListRowToggle(
          title: 'Reminders',
          value: false,
          onChanged: null,
        ),
      );
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    });

    testWidgets('grows with large text and stays the tap target', (
      tester,
    ) async {
      bool? changed;
      await tester.pumpApp(
        AppListRowToggle(
          title: 'Reminders',
          value: false,
          onChanged: (value) => changed = value,
        ),
        textScale: 2,
      );
      expect(
        tester.getSize(find.byType(AppListRow)).height,
        greaterThan(AppControlSize.listRow),
      );
      await tester.tap(find.text('Reminders'));
      expect(changed, isTrue);
    });
  });
}
