import 'dart:ui' show SemanticsAction;

import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

AppCarousel _carousel({double height = 120}) => AppCarousel(
  height: height,
  pages: [
    for (final name in ['One', 'Two', 'Three'])
      AppCard(child: Center(child: Text(name))),
  ],
);

/// The dots' colours, in order.
List<Color?> _dots(WidgetTester tester) => [
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(ExcludeSemantics),
      matching: find.byType(DecoratedBox),
    ),
  ))
    (box.decoration as BoxDecoration).color,
];

void main() {
  group('AppCarousel', () {
    testWidgets('swipes a page at a time, and the dots follow', (tester) async {
      await tester.pumpApp(_carousel());
      final scheme = AppTheme.light.colorScheme;
      final on = scheme.onSurfaceVariant;
      final off = scheme.outlineVariant;
      expect(find.text('One'), findsOneWidget);
      expect(_dots(tester), [on, off, off]);

      await tester.drag(find.text('One'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Two'), findsOneWidget);
      expect(find.text('One'), findsNothing);
      expect(_dots(tester), [off, on, off]);

      // The last page does not wrap round to the first.
      await tester.drag(find.text('Two'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Three'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Three'), findsOneWidget);
      expect(_dots(tester), [off, off, on]);
    });

    testWidgets('pages fill the width, and grow with the text', (tester) async {
      await tester.pumpApp(_carousel(), textScale: 2);
      final page = tester.getSize(find.byType(AppCard));
      expect(page.height, 240);
      expect(page.width, tester.getSize(find.byType(PageView)).width);
    });

    testWidgets('a vertical drag scrolls the list it sits in', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpApp(
        ListView(
          controller: controller,
          children: [_carousel(), const SizedBox(height: 2000)],
        ),
      );
      await tester.drag(find.text('One'), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(0));
      expect(find.text('Two'), findsNothing);
    });

    testWidgets('screen readers page with scroll actions, not the dots', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpApp(_carousel());
      expect(find.semantics.byAction(SemanticsAction.scrollLeft), findsOne);
      expect(
        find.semantics.byAction(SemanticsAction.scrollRight),
        findsNothing,
      );
      semantics.dispose();
    });
  });

  group('AppCarousel golden', () {
    goldenStates('app_carousel', [('Three pages', _carousel())]);
  });
}
