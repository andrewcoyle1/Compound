import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppIconBadge', () {
    testWidgets('is its size, and grows with the text', (tester) async {
      await tester.pumpApp(
        const Center(child: AppIconBadge(icon: AppSymbols.meal)),
        textScale: 2,
      );
      expect(
        tester.getSize(find.byType(AppIconBadge)),
        Size.square(AppIconSize.medium.points * 2),
      );
      expect(find.byIcon(AppSymbols.meal), findsOneWidget);
    });

    testWidgets('draws its badge, and is hidden from screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(
          child: AppIconBadge(
            icon: AppSymbols.meal,
            size: AppIconSize.hero,
            filled: false,
            badge: AppSymbols.edit,
          ),
        ),
      );
      expect(find.byIcon(AppSymbols.edit), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppIconBadge)),
        Size.square(AppIconSize.hero.points),
      );
      expect(
        find.descendant(
          of: find.byType(AppIconBadge),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      semantics.dispose();
    });
  });

  group('AppIconBadge golden', () {
    goldenStates('app_icon_badge', [
      ('Filled', const AppIconBadge(icon: AppSymbols.meal)),
      (
        'Ring with a badge',
        const AppIconBadge(
          icon: AppSymbols.meal,
          size: AppIconSize.hero,
          filled: false,
          badge: AppSymbols.edit,
        ),
      ),
    ], width: 160);
  });
}
