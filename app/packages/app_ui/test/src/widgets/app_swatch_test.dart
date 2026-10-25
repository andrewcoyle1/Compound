import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppSwatch', () {
    testWidgets('is its size, and grows with the text', (tester) async {
      await tester.pumpApp(
        const Center(child: AppSwatch(color: Color(0xFFFF9500))),
        textScale: 2,
      );
      expect(
        tester.getSize(find.byType(AppSwatch)),
        Size.square(AppIconSize.large.points * 2),
      );
    });

    testWidgets('draws its glyph, and is hidden from screen readers', (
      tester,
    ) async {
      await tester.pumpApp(
        const Center(
          child: AppSwatch(
            color: Color(0xFFFF9500),
            icon: AppSymbols.streak,
            size: AppIconSize.medium,
            selected: true,
          ),
        ),
      );
      expect(find.byIcon(AppSymbols.streak), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppSwatch)),
        Size.square(AppIconSize.medium.points),
      );
      expect(
        find.descendant(
          of: find.byType(AppSwatch),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
    });
  });

  group('AppSwatch golden', () {
    goldenStates('app_swatch', [
      ('Colour', const AppSwatch(color: Color(0xFFFF9500))),
      (
        'Glyph',
        const AppSwatch(color: Color(0xFF5856D6), icon: AppSymbols.streak),
      ),
      (
        'Selected',
        const AppSwatch(
          color: Color(0xFF5856D6),
          icon: AppSymbols.streak,
          selected: true,
        ),
      ),
    ], width: 120);
  });
}
