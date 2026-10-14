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
  });
}
