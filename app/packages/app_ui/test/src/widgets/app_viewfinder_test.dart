import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Stands in for a camera's picture.
const _picture = ColoredBox(color: Color(0xFF6B7F5A));

void main() {
  testWidgets('without a preview, shows the camera glyph and no guide', (
    tester,
  ) async {
    await tester.pumpApp(const AppViewfinder());
    expect(find.byIcon(AppSymbols.camera), findsOneWidget);
    expect(find.byType(DecoratedBox), findsNothing);
  });

  testWidgets('frames the preview, with its caption and action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpApp(
      AppViewfinder(
        preview: _picture,
        caption: 'Hold the label in the frame',
        action: AppIconButton(
          icon: AppSymbols.torchOff,
          semanticLabel: 'Turn on flashlight',
          onPressed: () {},
        ),
      ),
    );
    expect(find.byIcon(AppSymbols.camera), findsNothing);
    expect(find.byType(ColoredBox), findsWidgets);
    expect(find.byType(AppSpinner), findsNothing);
    expect(
      tester.getSemantics(find.text('Hold the label in the frame')),
      matchesSemantics(
        label: 'Hold the label in the frame',
        isLiveRegion: true,
      ),
    );
    expect(find.byTooltip('Turn on flashlight'), findsOneWidget);
    handle.dispose();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('at ${scale * 100}% text the caption sits under the guide, '
        'clear of its edge', (tester) async {
      await tester.pumpApp(
        const SizedBox(
          width: 343,
          child: AppViewfinder(
            preview: _picture,
            caption: 'Hold the label in the frame',
          ),
        ),
        textScale: scale,
      );
      final guide = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).border != null,
      );
      final caption = find.ancestor(
        of: find.text('Hold the label in the frame'),
        matching: find.byType(DecoratedBox),
      );
      expect(
        tester.getTopLeft(caption.first).dy,
        greaterThan(tester.getBottomLeft(guide).dy),
      );
      expect(
        tester.getBottomLeft(caption.first).dy,
        lessThanOrEqualTo(tester.getBottomLeft(find.byType(AppViewfinder)).dy),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a busy caption has a spinner', (tester) async {
    await tester.pumpApp(
      const AppViewfinder(caption: 'Reading label…', busy: true),
    );
    expect(find.byType(AppSpinner), findsOneWidget);
  });

  group('AppViewfinder golden', () {
    goldenStates('app_viewfinder', [
      ('Opening', const AppViewfinder()),
      (
        'Live, torch',
        AppViewfinder(
          preview: _picture,
          caption: 'Hold the label in the frame',
          action: AppIconButton(
            icon: AppSymbols.torchOff,
            semanticLabel: 'Turn on flashlight',
            onPressed: () {},
          ),
        ),
      ),
      ('Reading', const AppViewfinder(caption: 'Reading label…', busy: true)),
    ], pumpBeforeTest: pumpOnceSettled);
  });
}
