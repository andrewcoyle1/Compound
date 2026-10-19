import 'package:app_ui/app_ui.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AppSpinner, () {
    SpinKitFadingCircle dots(WidgetTester tester) =>
        tester.widget(find.byType(SpinKitFadingCircle));

    testWidgets('is the accent, silent, and regular size by default', (
      tester,
    ) async {
      await tester.pumpApp(const Center(child: AppSpinner()));
      expect(dots(tester).color, AppTheme.light.colorScheme.primary);
      expect(dots(tester).size, AppIconSize.medium.points);
      expect(
        tester.getSize(find.byType(AppSpinner)),
        Size.square(AppIconSize.medium.points),
      );
      expect(tester.getSemantics(find.byType(AppSpinner)).label, isEmpty);
    });

    testWidgets('takes a colour, and a small size that grows with text', (
      tester,
    ) async {
      await tester.pumpApp(
        const Center(
          child: AppSpinner(
            size: AppSpinnerSize.small,
            color: Color(0xFF00FF00),
          ),
        ),
        textScale: 2,
      );
      expect(dots(tester).color, const Color(0xFF00FF00));
      expect(dots(tester).size, AppIconSize.small.points * 2);
    });

    testWidgets('shrinks to fit a smaller slot', (tester) async {
      await tester.pumpApp(
        const Center(
          child: SizedBox.square(dimension: 10, child: AppSpinner()),
        ),
      );
      expect(tester.getSize(find.byType(AppSpinner)), const Size.square(10));
    });

    testWidgets('holds still under reduced motion', (tester) async {
      await tester.pumpApp(const Center(child: AppSpinner()));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('fades its dots in turn when animations are on', (
      tester,
    ) async {
      await tester.pumpApp(
        const Center(child: AppSpinner()),
        disableAnimations: false,
      );
      double firstDot() => tester
          .widget<FadeTransition>(
            find
                .descendant(
                  of: find.byType(SpinKitFadingCircle),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      final before = firstDot();
      await tester.pump(AppMotion.standard.duration);
      expect(firstDot(), isNot(before));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });
  });

  group(AppLoadingView, () {
    testWidgets('centres a spinner screen readers hear as its label', (
      tester,
    ) async {
      await tester.pumpApp(const AppLoadingView(label: 'Loading'));
      expect(find.byType(AppSpinner), findsOneWidget);
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

    testWidgets('holds still under reduced motion', (tester) async {
      await tester.pumpApp(const AppPlaceholder(height: 20));
      await tester.pumpAndSettle();
      expect(find.byType(Shimmer), findsNothing);
    });

    testWidgets('shimmers to a lighter grey when animations are on', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppPlaceholder(height: 20),
        disableAnimations: false,
      );
      final shimmer = tester.widget<Shimmer>(find.byType(Shimmer));
      expect(shimmer.direction, ShimmerDirection.ltr);
      expect(
        (shimmer.gradient as LinearGradient).colors,
        containsAll([
          AppTheme.light.colorScheme.surfaceContainerHighest,
          AppTheme.light.colorScheme.surfaceBright,
        ]),
      );
      await tester.pump(AppMotion.standard.duration);
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('sweeps right to left in a right-to-left language', (
      tester,
    ) async {
      await tester.pumpApp(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: AppPlaceholder(height: 20),
        ),
        disableAnimations: false,
      );
      expect(
        tester.widget<Shimmer>(find.byType(Shimmer)).direction,
        ShimmerDirection.rtl,
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

  group('AppSpinner golden', () {
    goldenStates('app_spinner', [
      ('Regular', const AppSpinner()),
      ('Small', const AppSpinner(size: AppSpinnerSize.small)),
      (
        'Small, on a disabled fill',
        Builder(
          builder: (context) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s),
              child: AppSpinner(
                size: AppSpinnerSize.small,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    ]);
  });

  group('AppLoading golden', () {
    goldenStates('app_loading', [
      ('Loading view', const AppLoadingView(label: 'Loading')),
      ('Placeholder', const AppPlaceholder(height: 20, width: 120)),
      ('Placeholder row', const AppCard(child: AppPlaceholderRow())),
      (
        'Placeholder row, leading, no subtitle',
        const AppCard(
          child: AppPlaceholderRow(hasLeading: true, hasSubtitle: false),
        ),
      ),
    ]);
  });
}
