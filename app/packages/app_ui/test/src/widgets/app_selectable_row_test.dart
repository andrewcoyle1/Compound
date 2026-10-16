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
        isSemantics(
          label: 'Lose weight',
          value: 'Even if your TDEE is lower',
          isButton: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('is one node, still after a route above it pops', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final options = ValueNotifier(['One']);
      await tester.pumpApp(
        Navigator(
          key: navigator,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => ValueListenableBuilder(
              valueListenable: options,
              builder: (_, values, _) => ListView(
                children: [
                  for (final value in values)
                    AppSelectableRow(
                      title: value,
                      selected: false,
                      onPressed: null,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('Above')),
      );
      await tester.pumpAndSettle();
      options.value = ['One', 'Two'];
      await tester.pump();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSemantics(find.byType(AppSelectableRow).last),
        isSemantics(
          label: 'Two',
          isButton: true,
          hasEnabledState: true,
          hasSelectedState: true,
        ),
      );
    });
  });
}
