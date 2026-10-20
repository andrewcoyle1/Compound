import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  final scheme = AppTheme.light.colorScheme;

  group(AppEmptyState, () {
    testWidgets('shows the icon, title, description and action', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpApp(
        AppEmptyState(
          icon: AppSymbols.meal,
          title: 'No Meals Logged',
          description: 'Meals you log today show up here.',
          actionLabel: 'Log a Meal',
          onAction: () => tapped++,
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(AppSymbols.meal));
      expect(icon.color, scheme.onSurfaceVariant);
      expect(find.text('Meals you log today show up here.'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('No Meals Logged')),
        matchesSemantics(label: 'No Meals Logged', isHeader: true),
      );

      await tester.tap(find.text('Log a Meal'));
      expect(tapped, 1);
    });

    testWidgets('leaves out what it is not given', (tester) async {
      await tester.pumpApp(
        const AppEmptyState(icon: AppSymbols.meal, title: 'No Meals'),
      );
      expect(find.byType(AppCtaButton), findsNothing);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('scrolls rather than overflows at 200% text', (tester) async {
      tester.view
        ..physicalSize = const Size(320, 480)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        AppEmptyState(
          icon: AppSymbols.meal,
          title: 'No Meals Logged',
          description: 'Meals you log today show up here. ' * 4,
          actionLabel: 'Log a Meal',
          onAction: () {},
        ),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    test('takes an action label and callback together', () {
      expect(
        () => AppEmptyState(
          icon: AppSymbols.meal,
          title: 'No Meals',
          actionLabel: 'Log',
        ),
        throwsAssertionError,
      );
    });
  });

  group(AppErrorState, () {
    testWidgets('shows the error glyph and is announced as it appears', (
      tester,
    ) async {
      var retried = 0;
      await tester.pumpApp(
        AppErrorState(
          title: "Couldn't Load Your Meals",
          description: 'Check your connection.',
          actionLabel: 'Try Again',
          onAction: () => retried++,
        ),
      );
      expect(find.byIcon(AppSymbols.error), findsOneWidget);
      final live = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byType(AppEmptyState),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(live.properties.liveRegion, isTrue);

      await tester.tap(find.text('Try Again'));
      expect(retried, 1);
    });

    testWidgets('takes its own glyph', (tester) async {
      await tester.pumpApp(
        const AppErrorState(title: 'Offline', icon: AppSymbols.sync),
      );
      expect(find.byIcon(AppSymbols.sync), findsOneWidget);
    });
  });

  group('AppEmptyState golden', () {
    goldenStates('app_empty_state', [
      (
        'Empty, with an action',
        AppEmptyState(
          icon: AppSymbols.workout,
          title: 'No workouts yet',
          description: 'Workouts you finish will show here.',
          actionLabel: 'Start a Workout',
          onAction: () {},
        ),
      ),
      (
        'Empty, title only',
        const AppEmptyState(icon: AppSymbols.search, title: 'No results'),
      ),
      (
        'Error',
        AppErrorState(
          title: "Couldn't load your workouts",
          description: 'Check your connection and try again.',
          actionLabel: 'Try Again',
          onAction: () {},
        ),
      ),
    ], padded: false);
  });
}
