import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

ShapeDecoration _ring(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(AppSelectionRing),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as ShapeDecoration;

void main() {
  group('AppSelectionRing', () {
    testWidgets('rings its child in the accent while selected', (tester) async {
      await tester.pumpApp(
        const AppSelectionRing(
          selected: true,
          radius: AppRadius.m,
          child: SizedBox.square(dimension: 44),
        ),
      );
      final side = (_ring(tester).shape as OutlinedBorder).side;
      expect(side.color, AppColors.light.accentInk);
      expect(side.width, AppSelectionRing.width);
    });

    testWidgets('draws no ring, as a circle, while not selected', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppSelectionRing(
          selected: false,
          filled: true,
          child: SizedBox.square(dimension: 44),
        ),
      );
      final shape = _ring(tester).shape;
      expect(shape, isA<CircleBorder>());
      expect((shape as CircleBorder).side, BorderSide.none);
    });
  });

  group('AppSelectionRing golden', () {
    goldenStates('app_selection_ring', [
      for (final selected in [false, true])
        (
          selected ? 'Selected' : 'Not selected',
          AppSelectionRing(
            selected: selected,
            radius: AppRadius.m,
            filled: true,
            child: const SizedBox(width: 88, height: 64),
          ),
        ),
      (
        'Circle',
        const AppSelectionRing(
          selected: true,
          child: SizedBox.square(dimension: 44),
        ),
      ),
    ], width: 120);
  });
}
