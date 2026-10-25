import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppFeatureRow', () {
    testWidgets('reads as one element', (tester) async {
      await tester.pumpApp(
        const AppFeatureRow(
          icon: AppSymbols.analytics,
          title: 'Progress tracking',
          detail: 'Trends at a glance.',
        ),
      );
      expect(
        tester.getSemantics(find.byType(AppFeatureRow)),
        isSemantics(label: 'Progress tracking\nTrends at a glance.'),
      );
    });

    testWidgets('starts the divider under it past the circle', (tester) async {
      await tester.pumpApp(
        const AppSection(
          children: [
            AppFeatureRow(icon: AppSymbols.analytics, title: 'One'),
            AppFeatureRow(icon: AppSymbols.heart, title: 'Two'),
          ],
        ),
      );
      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.indent, AppFeatureRow.textInset(TextScaler.noScaling));
    });
  });

  group('AppFeatureRow golden', () {
    goldenStates('app_feature_row', [
      (
        'Title and detail',
        const AppCard(
          child: AppFeatureRow(
            icon: AppSymbols.mesocycle,
            title: 'Personalized plans',
            detail: 'Training and nutrition tailored to your goals.',
          ),
        ),
      ),
      (
        'Title',
        const AppCard(
          child: AppFeatureRow(
            icon: AppSymbols.notifications,
            title: 'Accountability',
          ),
        ),
      ),
    ]);
  });
}
