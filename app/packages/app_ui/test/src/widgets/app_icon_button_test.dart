import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppIconButton', () {
    testWidgets('is labelled, tappable and at least 44 pt', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Center(
          child: AppIconButton(
            icon: AppSymbols.edit,
            semanticLabel: 'Edit',
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(AppIconButton));
      expect(taps, 1);
      expect(find.byTooltip('Edit'), findsOneWidget);
      final size = tester.getSize(find.byType(AppIconButton));
      expect(size.shortestSide, greaterThanOrEqualTo(AppControlSize.row));
    });

    testWidgets('plain is a labelled glyph with its count, 44 pt', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpApp(
        Center(
          child: AppIconButton.plain(
            icon: AppSymbols.like,
            semanticLabel: 'Like',
            label: '3',
            selected: true,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(AppIconButton));
      expect(taps, 1);
      expect(find.byTooltip('Like'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppIconButton)).shortestSide,
        greaterThanOrEqualTo(AppControlSize.row),
      );
      expect(
        tester.getSemantics(find.byType(AppIconButton)),
        matchesSemantics(
          label: 'Like',
          value: '3',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('plain without onPressed is faded and disabled', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppIconButton.plain(
          icon: AppSymbols.comment,
          semanticLabel: 'Comments',
          onPressed: null,
        ),
      );
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(AppIconButton),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, AppListRow.disabledOpacity);
    });

    testWidgets('grows with the text size', (tester) async {
      await tester.pumpApp(
        const Center(
          child: AppIconButton(
            icon: AppSymbols.edit,
            semanticLabel: 'Edit',
            onPressed: null,
          ),
        ),
        textScale: 2,
      );
      expect(
        tester.getSize(find.byType(AppIconButton)).height,
        AppControlSize.compact * 2,
      );
    });
  });

  group('AppIconButton golden', () {
    goldenStates('app_icon_button', [
      (
        'Enabled',
        AppIconButton(
          icon: AppSymbols.edit,
          semanticLabel: 'Edit',
          onPressed: () {},
        ),
      ),
      (
        'Destructive',
        AppIconButton(
          icon: AppSymbols.delete,
          semanticLabel: 'Delete',
          isDestructive: true,
          onPressed: () {},
        ),
      ),
      (
        'Disabled',
        const AppIconButton(
          icon: AppSymbols.edit,
          semanticLabel: 'Edit',
          onPressed: null,
        ),
      ),
      (
        'Plain: label and selected, plain, disabled',
        Row(
          children: [
            AppIconButton.plain(
              icon: AppSymbols.liked,
              semanticLabel: 'Unlike',
              label: '12',
              selected: true,
              onPressed: () {},
            ),
            AppIconButton.plain(
              icon: AppSymbols.comment,
              semanticLabel: 'Comments',
              onPressed: () {},
            ),
            const AppIconButton.plain(
              icon: AppSymbols.reply,
              semanticLabel: 'Reply',
              onPressed: null,
            ),
          ],
        ),
      ),
    ], width: 240);
  });
}
