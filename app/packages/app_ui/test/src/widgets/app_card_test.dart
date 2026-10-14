import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

Material _material(WidgetTester tester) => tester.widget<Material>(
  find.descendant(of: find.byType(AppCard), matching: find.byType(Material)),
);

void main() {
  group('AppCard', () {
    testWidgets('a card is the surface with the xl radius', (tester) async {
      await tester.pumpApp(const AppCard(child: Text('Card')));
      final material = _material(tester);
      expect(find.text('Card'), findsOneWidget);
      expect(material.color, AppColors.light.surface);
      expect(
        (material.shape! as RoundedSuperellipseBorder).borderRadius,
        const BorderRadius.all(Radius.circular(AppRadius.xl)),
      );
    });

    testWidgets('a tile has the l radius', (tester) async {
      await tester.pumpApp(
        const AppCard(style: AppCardStyle.tile, child: SizedBox()),
      );
      expect(
        (_material(tester).shape! as RoundedSuperellipseBorder).borderRadius,
        const BorderRadius.all(Radius.circular(AppRadius.l)),
      );
    });

    testWidgets('a tinted tile fills with the tinted surface', (tester) async {
      await tester.pumpApp(
        AppCard(
          style: AppCardStyle.tinted(AppColors.light.protein),
          child: const SizedBox(),
        ),
      );
      expect(
        _material(tester).color,
        AppColors.tintedSurface(AppColors.light.protein),
      );
    });
  });
}
