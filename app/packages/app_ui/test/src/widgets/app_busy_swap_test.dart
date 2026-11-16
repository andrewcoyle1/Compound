import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AppBusySwap, () {
    late List<bool> built;

    Widget swap({required bool busy}) => Center(
      child: AppBusySwap(
        busy: busy,
        idle: const Text('Save'),
        spinner: const AppSpinner(size: AppSpinnerSize.small),
        builder: (context, content, {required busy}) {
          built.add(busy);
          return content;
        },
      ),
    );

    double opacityOf(WidgetTester tester, Finder finder) => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(of: finder, matching: find.byType(AnimatedOpacity))
              .first,
        )
        .opacity;

    setUp(() => built = []);

    testWidgets('is busy at once but shows the spinner only after a wait', (
      tester,
    ) async {
      await tester.pumpApp(swap(busy: false));
      expect(find.byType(AppSpinner), findsNothing);
      expect(built.last, isFalse);

      await tester.pumpApp(swap(busy: true));
      expect(built.last, isTrue);
      expect(opacityOf(tester, find.text('Save')), 1);
      expect(opacityOf(tester, find.byType(AppSpinner)), 0);

      await tester.pump(
        AppBusySwap.showAfter - const Duration(milliseconds: 1),
      );
      expect(opacityOf(tester, find.byType(AppSpinner)), 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(opacityOf(tester, find.byType(AppSpinner)), 1);
      expect(opacityOf(tester, find.text('Save')), 0);

      await tester.pumpApp(swap(busy: false));
      await tester.pump(AppBusySwap.holdFor);
      await tester.pumpAndSettle();
    });

    testWidgets('a quick answer never shows the spinner', (tester) async {
      await tester.pumpApp(swap(busy: true));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpApp(swap(busy: false));
      expect(built.last, isFalse);
      expect(find.byType(AppSpinner), findsNothing);
      await tester.pump(AppBusySwap.showAfter);
      expect(find.byType(AppSpinner), findsNothing);
      expect(opacityOf(tester, find.text('Save')), 1);
    });

    testWidgets('holds a shown spinner, and stays busy, for holdFor', (
      tester,
    ) async {
      await tester.pumpApp(swap(busy: true));
      await tester.pump(AppBusySwap.showAfter);
      expect(opacityOf(tester, find.byType(AppSpinner)), 1);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpApp(swap(busy: false));
      expect(built.last, isTrue);
      expect(opacityOf(tester, find.byType(AppSpinner)), 1);

      await tester.pump(
        AppBusySwap.holdFor - const Duration(milliseconds: 100),
      );
      expect(built.last, isFalse);
      expect(opacityOf(tester, find.text('Save')), 1);
      await tester.pumpAndSettle();
      expect(find.byType(AppSpinner), findsNothing);
    });

    testWidgets('lets the spinner go at once if the hold is already over', (
      tester,
    ) async {
      await tester.pumpApp(swap(busy: true));
      await tester.pump(AppBusySwap.showAfter);
      await tester.pump(AppBusySwap.holdFor);
      await tester.pumpApp(swap(busy: false));
      expect(built.last, isFalse);
      expect(opacityOf(tester, find.text('Save')), 1);
      await tester.pumpAndSettle();
      expect(find.byType(AppSpinner), findsNothing);
    });

    testWidgets('fades the spinner out with animations on', (tester) async {
      await tester.pumpApp(swap(busy: true), disableAnimations: false);
      await tester.pump(AppBusySwap.showAfter);
      await tester.pump(AppBusySwap.holdFor);
      await tester.pumpApp(swap(busy: false), disableAnimations: false);
      await tester.pump();
      await tester.pump(AppMotion.quick.duration ~/ 2);
      expect(find.byType(AppSpinner), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(AppSpinner), findsNothing);
    });

    testWidgets('waits again when busy starts while the spinner is held', (
      tester,
    ) async {
      await tester.pumpApp(swap(busy: true));
      await tester.pump(AppBusySwap.showAfter);
      await tester.pumpApp(swap(busy: false));
      await tester.pumpApp(swap(busy: true));
      expect(opacityOf(tester, find.byType(AppSpinner)), 1);
      await tester.pump(AppBusySwap.holdFor);
      expect(opacityOf(tester, find.byType(AppSpinner)), 1);
      await tester.pumpApp(swap(busy: false));
      await tester.pumpAndSettle();
      expect(find.byType(AppSpinner), findsNothing);
    });

    testWidgets('built busy, it waits before the spinner', (tester) async {
      await tester.pumpApp(swap(busy: true));
      expect(opacityOf(tester, find.byType(AppSpinner)), 0);
      await tester.pump(AppBusySwap.showAfter);
      expect(opacityOf(tester, find.byType(AppSpinner)), 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('keeps the size of its idle content', (tester) async {
      await tester.pumpApp(swap(busy: false));
      final idle = tester.getSize(find.byType(Stack).last);
      await tester.pumpApp(swap(busy: true));
      await tester.pump(AppBusySwap.showAfter);
      expect(tester.getSize(find.byType(Stack).last), idle);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
