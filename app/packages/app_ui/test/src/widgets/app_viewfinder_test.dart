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
    expect(find.byType(CircularProgressIndicator), findsNothing);
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

  testWidgets('a busy caption has a spinner', (tester) async {
    await tester.pumpApp(
      const AppViewfinder(caption: 'Reading label…', busy: true),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
