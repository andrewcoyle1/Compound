import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppSelectableRow', () {
    testWidgets('is a selected button with a check', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        AppSelectableRow(
          title: 'Lose weight',
          subtitle: 'Even if your TDEE is lower',
          selected: true,
          onPressed: () => taps++,
        ),
      );
      await tester.tap(find.byType(AppSelectableRow));
      expect(taps, 1);
      expect(find.byIcon(AppSymbols.choiceSelected), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(AppSelectableRow)),
        isSemantics(isButton: true, isSelected: true),
      );
    });
  });
}
