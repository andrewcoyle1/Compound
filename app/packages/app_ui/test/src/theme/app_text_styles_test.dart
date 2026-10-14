import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppTextStyles', () {
    test('metrics use tabular figures', () {
      for (final style in [
        AppTextStyles.metricLarge,
        AppTextStyles.metric,
        AppTextStyles.metricSmall,
      ]) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });

    test('match iOS text styles at the default size', () {
      expect(AppTextStyles.display.fontSize, 34);
      expect(AppTextStyles.rowTitle.fontSize, 17);
      expect(AppTextStyles.rowDetail.fontSize, 15);
      expect(AppTextStyles.label.fontSize, 12);
    });

    test('carry no colour, so text takes the theme', () {
      expect(AppTextStyles.textTheme.bodyMedium?.color, isNull);
    });
  });

  group('AppIconSize', () {
    testWidgets('scales with the text size', (tester) async {
      late double size;
      await tester.pumpApp(
        Builder(
          builder: (context) {
            size = AppIconSize.medium.of(context);
            return const SizedBox();
          },
        ),
        textScale: 2,
      );
      expect(size, 48);
      expect(AppIconSize.hero.points, 64);
    });
  });
}
