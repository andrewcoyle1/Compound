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

    testWidgets('inline lines up with the text before it', (tester) async {
      await tester.pumpApp(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detail'),
            AppTextButton(label: 'Edit', onPressed: () {}, inline: true),
          ],
        ),
      );
      expect(
        tester.getTopLeft(find.text('Edit')).dx,
        tester.getTopLeft(find.text('Detail')).dx,
      );
      expect(
        tester.getSize(find.byType(TextButton)).height,
        greaterThanOrEqualTo(AppControlSize.row),
      );
      final style = tester
          .widget<TextButton>(find.byType(TextButton))
          .style!
          .textStyle!
          .resolve({})!;
      expect(style.fontWeight, FontWeight.w600);
      expect(style.fontSize, AppTextStyles.rowDetail.fontSize);
    });

    testWidgets('null onPressed disables it', (tester) async {
      await tester.pumpApp(const AppTextButton(label: 'Skip', onPressed: null));
      expect(tester.widget<TextButton>(find.byType(TextButton)).enabled, false);
    });
  });

  group('AppTextButton golden', () {
    goldenStates('app_text_button', [
      ('Enabled', AppTextButton(label: 'See All', onPressed: () {})),
      (
        'Destructive',
        AppTextButton(label: 'Remove', onPressed: () {}, isDestructive: true),
      ),
      ('Disabled', const AppTextButton(label: 'Not now', onPressed: null)),
      (
        'Inline',
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppTextButton(
            label: 'Edit Weights',
            onPressed: () {},
            inline: true,
          ),
        ),
      ),
    ], width: 220);
  });
}
