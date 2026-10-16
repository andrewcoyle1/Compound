import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppStat', () {
    testWidgets('reads as one element, label then value', (tester) async {
      await tester.pumpApp(const AppStat(value: '82.5 kg', label: 'Weight'));
      expect(
        tester.getSemantics(find.byType(AppStat)),
        matchesSemantics(label: 'Weight', value: '82.5 kg'),
      );
    });

    testWidgets('sizes the value by its size', (tester) async {
      await tester.pumpApp(
        const AppStat(
          value: '1,850',
          label: 'Calories',
          size: AppStatSize.large,
        ),
      );
      expect(
        tester.widget<Text>(find.text('1,850')).style,
        AppTextStyles.metricLarge,
      );
    });

    testWidgets('draws the icon in the tint, else secondary', (tester) async {
      await tester.pumpApp(
        const Column(
          children: [
            AppStat(
              value: '12',
              label: 'Streak',
              icon: AppSymbols.streak,
              tint: Color(0xFFFF9500),
            ),
            AppStat(
              value: '54:12',
              label: 'Duration',
              icon: AppSymbols.duration,
            ),
          ],
        ),
      );
      final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
      expect(icons[0].color, const Color(0xFFFF9500));
      expect(icons[1].color, AppTheme.light.colorScheme.onSurfaceVariant);
      expect(icons[0].size, AppTextStyles.metric.fontSize);
    });
  });

  group('AppStatTile', () {
    testWidgets('sits on a tile without a tint', (tester) async {
      await tester.pumpApp(const AppStatTile(value: '3', label: 'Workouts'));
      final card = tester.widget<AppCard>(find.byType(AppCard));
      expect(card.style, same(AppCardStyle.tile));
      expect(find.byType(AppStat), findsOneWidget);
    });

    testWidgets('sits on a tinted tile with a tint', (tester) async {
      await tester.pumpApp(
        AppStatTile(
          value: '142 g',
          label: 'Protein',
          icon: AppSymbols.protein,
          tint: AppColors.light.protein,
        ),
      );
      final card = tester.widget<AppCard>(find.byType(AppCard));
      expect(card.style.tint, AppColors.light.protein);
      expect(
        tester.widget<AppStat>(find.byType(AppStat)).tint,
        AppColors.light.protein,
      );
    });
  });
}
