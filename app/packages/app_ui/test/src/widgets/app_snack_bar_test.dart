import 'package:app_ui/app_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// A button that shows a snack bar through [show].
Widget _trigger(void Function(BuildContext context) show) => Builder(
  builder: (context) =>
      AppTextButton(label: 'Show', onPressed: () => show(context)),
);

void main() {
  group('showAppSnackBar', () {
    for (final (style, icon) in [
      (AppSnackBarStyle.info, AppSymbols.info),
      (AppSnackBarStyle.success, AppSymbols.success),
      (AppSnackBarStyle.error, AppSymbols.error),
    ]) {
      testWidgets('shows ${style.name} with its icon, then goes', (
        tester,
      ) async {
        await tester.pumpApp(
          _trigger(
            (context) => showAppSnackBar(context, 'Saved', style: style),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();
        expect(find.text('Saved'), findsOneWidget);
        expect(find.byIcon(icon), findsOneWidget);

        await tester.pump(AppSnackBarScopeState.defaultDuration);
        await tester.pumpAndSettle();
        expect(find.byType(AppSnackBar), findsNothing);
      });
    }

    testWidgets('stays for the duration it is given', (tester) async {
      await tester.pumpApp(
        _trigger(
          (context) => showAppSnackBar(
            context,
            'Saving',
            duration: const Duration(seconds: 8),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Saving'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Saving'), findsNothing);
    });

    testWidgets('with an action, stays until it is tapped', (tester) async {
      var undone = 0;
      await tester.pumpApp(
        _trigger(
          (context) => showAppSnackBar(
            context,
            'Set deleted',
            action: AppSnackBarAction(label: 'Undo', onPressed: () => undone++),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Set deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('Set deleted'), findsNothing);
    });

    testWidgets('shows one at a time', (tester) async {
      var count = 0;
      await tester.pumpApp(
        _trigger((context) => showAppSnackBar(context, 'Notice ${++count}')),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('Notice 1'), findsNothing);
      expect(find.text('Notice 2'), findsOneWidget);
    });

    testWidgets('swipes down to dismiss', (tester) async {
      await tester.pumpApp(
        _trigger((context) => showAppSnackBar(context, 'Swipe me')),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.fling(find.text('Swipe me'), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Swipe me'), findsNothing);
    });

    testWidgets('is a live region screen readers can dismiss', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        _trigger((context) => showAppSnackBar(context, 'Report sent')),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      final node = tester.getSemantics(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      );
      expect(node.flagsCollection.isLiveRegion, isTrue);
      tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.dismiss,
      );
      await tester.pumpAndSettle();
      expect(find.text('Report sent'), findsNothing);
      handle.dispose();
    });

    testWidgets('appears at once when motion is reduced', (tester) async {
      await tester.pumpApp(
        _trigger((context) => showAppSnackBar(context, 'Saved')),
        disableAnimations: true,
      );
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(
        tester
            .widget<FadeTransition>(
              find
                  .ancestor(
                    of: find.byType(AppSnackBar),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value,
        1,
      );
    });

    testWidgets('keeps the screen beneath as it was', (tester) async {
      await tester.pumpApp(
        _trigger((context) => showAppSnackBar(context, 'Saved')),
      );
      final screen = tester.state(find.byType(Navigator));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(Navigator)), same(screen));
    });

    testWidgets('needs an AppSnackBarScope', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              expect(
                () => showAppSnackBar(context, 'Saved'),
                throwsA(isA<FlutterError>()),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('a scope that has gone shows nothing', (tester) async {
      await tester.pumpApp(const SizedBox.shrink());
      final scope = tester.state<AppSnackBarScopeState>(
        find.byType(AppSnackBarScope),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      scope.show('Saved');
      await tester.pump();
      expect(find.text('Saved'), findsNothing);
    });
  });

  group('AppSnackBarClearance', () {
    double snackBarBottom(WidgetTester tester) =>
        tester.getBottomLeft(find.byType(AppSnackBar)).dy;

    testWidgets('sits above a bottom call to action', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: _trigger((context) => showAppSnackBar(context, 'Saved')),
          bottomNavigationBar: AppBottomCta(
            children: [AppCtaButton(label: 'Save', onPressed: () {})],
          ),
        ),
        scaffold: false,
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(
        snackBarBottom(tester),
        lessThanOrEqualTo(tester.getTopLeft(find.byType(AppBottomCta)).dy),
      );
    });

    testWidgets('ignores a bar that is not along the bottom edge', (
      tester,
    ) async {
      await tester.pumpApp(
        Column(
          children: [
            const AppSnackBarClearance(child: SizedBox(height: 100)),
            _trigger((context) => showAppSnackBar(context, 'Saved')),
          ],
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      final screen = tester.getSize(find.byType(AppSnackBarScope)).height;
      expect(snackBarBottom(tester), screen - AppSpacing.s);
    });

    testWidgets('ignores a bar that is not on screen', (tester) async {
      await tester.pumpApp(
        Scaffold(
          body: _trigger((context) => showAppSnackBar(context, 'Saved')),
          bottomNavigationBar: TickerMode(
            enabled: false,
            child: AppBottomCta(
              children: [AppCtaButton(label: 'Save', onPressed: () {})],
            ),
          ),
        ),
        scaffold: false,
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      final screen = tester.getSize(find.byType(AppSnackBarScope)).height;
      expect(snackBarBottom(tester), screen - AppSpacing.s);
    });

    testWidgets('moves when a bar comes or goes', (tester) async {
      final showBar = ValueNotifier(false);
      addTearDown(showBar.dispose);
      await tester.pumpApp(
        ValueListenableBuilder(
          valueListenable: showBar,
          builder: (_, show, _) => Scaffold(
            body: _trigger((context) => showAppSnackBar(context, 'Saved')),
            bottomNavigationBar: show
                ? AppBottomCta(
                    children: [AppCtaButton(label: 'Save', onPressed: () {})],
                  )
                : null,
          ),
        ),
        scaffold: false,
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      final screen = tester.getSize(find.byType(AppSnackBarScope)).height;
      expect(snackBarBottom(tester), screen - AppSpacing.s);

      showBar.value = true;
      await tester.pumpAndSettle();
      final barTop = tester.getTopLeft(find.byType(AppBottomCta)).dy;
      expect(snackBarBottom(tester), barTop - AppSpacing.s);

      showBar.value = false;
      await tester.pumpAndSettle();
      expect(snackBarBottom(tester), screen - AppSpacing.s);
    });

    testWidgets('sits above the keyboard', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        _trigger((context) => showAppSnackBar(context, 'Saved')),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      final screen = tester.getSize(find.byType(AppSnackBarScope)).height;
      expect(
        snackBarBottom(tester),
        screen - 300 / tester.view.devicePixelRatio - AppSpacing.s,
      );
    });
  });

  group('AppSnackBar golden', () {
    goldenStates('app_snack_bar', [
      ('Info', const AppSnackBar(message: 'Report sent.')),
      (
        'Success',
        const AppSnackBar(message: 'Saved', style: AppSnackBarStyle.success),
      ),
      (
        'Error',
        const AppSnackBar(
          message: "Couldn't save. Try again.",
          style: AppSnackBarStyle.error,
        ),
      ),
      (
        'With action',
        AppSnackBar(
          message: 'Set deleted',
          action: AppSnackBarAction(label: 'Undo', onPressed: () {}),
        ),
      ),
    ]);
  });
}
