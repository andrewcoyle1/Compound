import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

ShapeDecoration _decoration(WidgetTester tester) =>
    tester.widget<DecoratedBox>(find.byType(DecoratedBox).last).decoration
        as ShapeDecoration;

void main() {
  group('AppChip', () {
    testWidgets('unselected is the tint on its tinted surface', (tester) async {
      await tester.pumpApp(const AppChip(label: 'All'));
      final accent = AppTheme.light.colorScheme.primary;
      expect(_decoration(tester).color, AppColors.tintedSurface(accent));
      expect(tester.widget<Text>(find.text('All')).style?.color, accent);
      expect(tester.getSize(find.byType(AppChip)).height, lessThan(44));
    });

    testWidgets('selected is filled, with onPrimary text', (tester) async {
      await tester.pumpApp(
        AppChip(
          label: 'Protein',
          icon: AppSymbols.protein,
          tint: AppColors.light.protein,
          selected: true,
        ),
      );
      final scheme = AppTheme.light.colorScheme;
      expect(_decoration(tester).color, AppColors.light.protein);
      expect(tester.widget<Icon>(find.byType(Icon)).color, scheme.onPrimary);
      expect(
        tester.getSemantics(find.byType(AppChip)),
        matchesSemantics(
          label: 'Protein',
          isSelected: true,
          hasSelectedState: true,
        ),
      );
    });

    testWidgets('as a button it has a 44 pt target and taps', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Center(
          child: AppChip(label: 'Filter', onPressed: () => taps++),
        ),
      );
      final size = tester.getSize(find.byType(InkWell));
      expect(size.height, greaterThanOrEqualTo(AppControlSize.row));
      expect(size.width, greaterThanOrEqualTo(AppControlSize.row));
      await tester.tap(find.byType(AppChip));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byType(AppChip)),
        isSemantics(label: 'Filter', isButton: true, hasTapAction: true),
      );
    });
  });
}
