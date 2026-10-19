import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppTextButton', () {
    testWidgets('calls onPressed with a 44 pt target', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Center(
          child: AppTextButton(label: 'See All', onPressed: () => taps++),
        ),
      );
      await tester.tap(find.text('See All'));
      expect(taps, 1);
      expect(
        tester.getSize(find.byType(TextButton)).height,
        greaterThanOrEqualTo(AppControlSize.row),
      );
    });

    testWidgets('destructive is still a button', (tester) async {
      await tester.pumpApp(
        AppTextButton(label: 'Delete', onPressed: () {}, isDestructive: true),
      );
      expect(
        tester.getSemantics(find.byType(AppTextButton)),
        isSemantics(label: 'Delete', isButton: true, isEnabled: true),
      );
    });

    testWidgets('null onPressed disables it', (tester) async {
      await tester.pumpApp(const AppTextButton(label: 'Skip', onPressed: null));
      expect(tester.widget<TextButton>(find.byType(TextButton)).enabled, false);
    });
  });
}
