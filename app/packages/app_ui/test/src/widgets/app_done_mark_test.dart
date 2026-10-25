import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppDoneMark', () {
    testWidgets('is a black tick on volt, the size of an icon', (tester) async {
      await tester.pumpApp(const Center(child: AppDoneMark()), textScale: 2);
      expect(
        tester.getSize(find.byType(AppDoneMark)),
        Size.square(AppIconSize.medium.points * 2),
      );
      final tick = tester.widget<Icon>(find.byIcon(AppSymbols.selected));
      final theme = AppTheme.light;
      expect(tick.color, theme.colorScheme.onPrimary);
      final disc = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AppDoneMark),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (disc.decoration as ShapeDecoration).color,
        theme.colorScheme.primary,
      );
    });
  });

  group('AppDoneMark golden', () {
    goldenStates('app_done_mark', [
      ('Medium', const AppDoneMark()),
      ('Small', const AppDoneMark(size: AppIconSize.small)),
    ], width: 120);
  });
}
