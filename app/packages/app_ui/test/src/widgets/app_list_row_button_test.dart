import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

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
  });
}
