import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AppLoadingView, () {
    testWidgets('centres a spinner screen readers hear as its label', (
      tester,
    ) async {
      await tester.pumpApp(const AppLoadingView(label: 'Loading'));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });
  });

  group(AppPlaceholder, () {
    testWidgets('is a grey shape of the size given', (tester) async {
      await tester.pumpApp(
        const Center(child: AppPlaceholder(width: 80, height: 20)),
      );
      expect(tester.getSize(find.byType(AppPlaceholder)), const Size(80, 20));
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AppPlaceholder),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        (box.decoration as ShapeDecoration).color,
        AppTheme.light.colorScheme.surfaceContainerHighest,
      );
    });

    testWidgets('is silent unless it carries a label', (tester) async {
      await tester.pumpApp(
        const Column(
          children: [
            AppPlaceholder(height: 20, semanticLabel: 'Loading'),
            AppPlaceholder(height: 20),
          ],
        ),
      );
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });
  });

  group(AppPlaceholderRow, () {
    testWidgets('is a list row tall, with a leading square when asked', (
      tester,
    ) async {
      await tester.pumpApp(
        const Column(
          children: [
            AppPlaceholderRow(hasLeading: true, semanticLabel: 'Loading'),
            AppPlaceholderRow(hasSubtitle: false),
          ],
        ),
      );
      final rows = find.byType(AppPlaceholderRow);
      expect(
        tester.getSize(rows.first).height,
        greaterThanOrEqualTo(AppControlSize.listRow),
      );
      expect(
        find.descendant(of: rows.first, matching: find.byType(AppPlaceholder)),
        findsNWidgets(3),
      );
      expect(
        find.descendant(of: rows.last, matching: find.byType(AppPlaceholder)),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });

    testWidgets('grows with the text size', (tester) async {
      const rows = Column(children: [AppPlaceholderRow()]);
      await tester.pumpApp(rows);
      final regular = tester.getSize(find.byType(AppPlaceholderRow)).height;
      await tester.pumpApp(rows, textScale: 2);
      expect(
        tester.getSize(find.byType(AppPlaceholderRow)).height,
        greaterThan(regular),
      );
    });
  });
}
