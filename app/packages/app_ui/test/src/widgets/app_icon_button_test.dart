import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppIconButton', () {
    testWidgets('is labelled, tappable and at least 44 pt', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Center(
          child: AppIconButton(
            icon: AppSymbols.edit,
            semanticLabel: 'Edit',
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(AppIconButton));
      expect(taps, 1);
      expect(find.byTooltip('Edit'), findsOneWidget);
      final size = tester.getSize(find.byType(AppIconButton));
      expect(size.shortestSide, greaterThanOrEqualTo(AppControlSize.row));
    });

    testWidgets('grows with the text size', (tester) async {
      await tester.pumpApp(
        const Center(
          child: AppIconButton(
            icon: AppSymbols.edit,
            semanticLabel: 'Edit',
            onPressed: null,
          ),
        ),
        textScale: 2,
      );
      expect(
        tester.getSize(find.byType(AppIconButton)).height,
        AppControlSize.compact * 2,
      );
    });
  });

  group('AppIconButton golden', () {
    goldenStates('app_icon_button', [
      (
        'Enabled',
        AppIconButton(
          icon: AppSymbols.edit,
          semanticLabel: 'Edit',
          onPressed: () {},
        ),
      ),
      (
        'Disabled',
        const AppIconButton(
          icon: AppSymbols.edit,
          semanticLabel: 'Edit',
          onPressed: null,
        ),
      ),
    ], width: 160);
  });
}
