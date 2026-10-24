import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppFloatingButton', () {
    testWidgets('is a raised 44 pt capsule button that taps', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Center(
          child: AppFloatingButton(
            icon: AppSymbols.jumpToLatest,
            label: 'Jump to Latest',
            onPressed: () => taps++,
          ),
        ),
      );
      final scheme = AppTheme.light.colorScheme;
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(AppFloatingButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, scheme.surfaceContainerHigh);
      expect(material.elevation, greaterThan(0));
      expect(
        tester.getSize(find.byType(AppFloatingButton)).height,
        greaterThanOrEqualTo(AppControlSize.row),
      );

      await tester.tap(find.text('Jump to Latest'));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byType(AppFloatingButton)),
        isSemantics(
          label: 'Jump to Latest',
          isButton: true,
          hasTapAction: true,
        ),
      );
    });
  });

  group('AppFloatingButton golden', () {
    goldenStates('app_floating_button', [
      (
        'Jump to latest',
        Center(
          child: AppFloatingButton(
            icon: AppSymbols.jumpToLatest,
            label: 'Jump to Latest',
            onPressed: () {},
          ),
        ),
      ),
    ], width: 240);
  });
}
