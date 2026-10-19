import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:app_ui/app_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show DefaultCupertinoLocalizations;
import 'package:flutter_test/flutter_test.dart';

/// One state of a widget in a golden image: a name and the widget.
typedef GoldenState = (String name, Widget widget);

const List<(String, Brightness, double)> _variants = [
  ('light', Brightness.light, 1.0),
  ('dark', Brightness.dark, 1.0),
  ('200%', Brightness.light, 2.0),
];

/// One golden image for a widget, `goldens/ci/<fileName>.png` beside the
/// test: a row per state, each drawn in light mode, dark mode and light mode
/// at 200% text (ui-contract.md, rule 6).
///
/// Each cell is [width] wide on the theme's canvas, padded unless [padded]
/// is false; [height] fixes its height, which a screen-sized widget needs.
/// [pumpBeforeTest] replaces the default settle, for a widget that never
/// settles (a spinner).
void goldenStates(
  String fileName,
  List<GoldenState> states, {
  double width = 343,
  double? height,
  bool padded = true,
  PumpAction pumpBeforeTest = onlyPumpAndSettle,
}) => unawaited(
  goldenTest(
    'matches its golden in light, dark and at 200% text',
    fileName: fileName,
    pumpBeforeTest: pumpBeforeTest,
    builder: () => Localizations(
      locale: const Locale('en'),
      delegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      child: GoldenTestGroup(
        columns: _variants.length,
        // Fixed, so the table never asks a cell for its intrinsic size,
        // which a LayoutBuilder cannot answer.
        columnWidthBuilder: (_) => FixedColumnWidth(width + 2 * 8),
        children: [
          for (final (name, widget) in states)
            for (final (variant, brightness, textScale) in _variants)
              GoldenTestScenario(
                name: '$name · $variant',
                child: _Cell(
                  theme: brightness == Brightness.dark
                      ? AppTheme.dark
                      : AppTheme.light,
                  textScale: textScale,
                  width: width,
                  height: height,
                  padded: padded,
                  child: widget,
                ),
              ),
        ],
      ),
    ),
  ),
);

/// [child] as it looks on iOS: the platform-adaptive widgets (alerts,
/// switches, spinners) take their Cupertino form.
Widget onIos(Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
    child: child,
  ),
);

/// A pump for a golden whose widget never settles, such as a spinner:
/// one frame, then one more a fixed time later.
Future<void> pumpOnceSettled(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

class _Cell extends StatelessWidget {
  const new({
    required this.theme,
    required this.textScale,
    required this.width,
    required this.height,
    required this.padded,
    required this.child,
  });

  final ThemeData theme;
  final double textScale;
  final double width;
  final double? height;
  final bool padded;
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: theme,
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: Material(
          color: context.appColors.canvas,
          child: SizedBox(
            width: width,
            height: height,
            child: Padding(
              padding: EdgeInsets.all(padded ? AppSpacing.l : 0),
              // Loose, so a widget that sizes to its content does.
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                heightFactor: 1,
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
