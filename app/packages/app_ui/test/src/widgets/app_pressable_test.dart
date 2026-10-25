import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

const _dot = SizedBox.square(key: Key('dot'), dimension: 12);

void main() {
  group('AppPressable', () {
    testWidgets('taps, long-presses and reads as a button', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      var longPresses = 0;
      await tester.pumpApp(
        Center(
          child: AppPressable(
            onTap: () => taps++,
            onLongPress: () => longPresses++,
            child: const Text('Open'),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.longPress(find.text('Open'));
      expect((taps, longPresses), (1, 1));
      expect(find.byType(InkWell), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Open')),
        isSemantics(
          label: 'Open',
          isButton: true,
          hasTapAction: true,
          hasLongPressAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('without a tap is not a button', (tester) async {
      final semantics = tester.ensureSemantics();
      var longPresses = 0;
      await tester.pumpApp(
        Center(
          child: AppPressable(
            onTap: null,
            onLongPress: () => longPresses++,
            child: const Text('Row'),
          ),
        ),
      );
      await tester.longPress(find.text('Row'));
      expect(longPresses, 1);
      expect(
        tester.getSemantics(find.text('Row')),
        isSemantics(label: 'Row', hasLongPressAction: true),
      );
      semantics.dispose();
    });

    testWidgets('plays its haptic before the tap', (tester) async {
      final played = <Object>[];
      AppHaptics.debugPlay = played.add;
      addTearDown(() => AppHaptics.debugPlay = null);
      await tester.pumpApp(
        Center(
          child: AppPressable(
            haptic: AppHaptic.selection,
            onTap: () => played.add('tap'),
            child: const Text('Pick'),
          ),
        ),
      );
      await tester.tap(find.text('Pick'));
      expect(played, [AppHaptic.selection, 'tap']);
    });

    testWidgets('a small child is centred in a 44 pt target that takes '
        'a press anywhere', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Center(
          child: AppPressable(onTap: () => taps++, child: _dot),
        ),
      );
      final target = find.byType(AppPressable);
      expect(tester.getSize(target), const Size.square(AppControlSize.row));
      expect(
        tester.getSize(find.byKey(const Key('dot'))),
        const Size.square(12),
      );
      expect(
        tester.getCenter(find.byKey(const Key('dot'))),
        tester.getCenter(target),
      );
      await tester.tapAt(tester.getTopLeft(target) + const Offset(2, 2));
      expect(taps, 1);
    });

    testWidgets('a large child keeps its size', (tester) async {
      await tester.pumpApp(
        Center(
          child: AppPressable(
            onTap: () {},
            child: const SizedBox(width: 200, height: 60),
          ),
        ),
      );
      expect(tester.getSize(find.byType(AppPressable)), const Size(200, 60));
    });

    testWidgets('reports at least 44 pt to intrinsic and dry layout', (
      tester,
    ) async {
      await tester.pumpApp(
        Center(
          child: IntrinsicWidth(
            child: IntrinsicHeight(
              child: AppPressable(onTap: () {}, child: _dot),
            ),
          ),
        ),
      );
      final box = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(AppPressable),
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_MinimumTarget',
          ),
        ),
      );
      expect(box.getMinIntrinsicWidth(double.infinity), AppControlSize.row);
      expect(box.getMaxIntrinsicWidth(double.infinity), AppControlSize.row);
      expect(box.getMinIntrinsicHeight(double.infinity), AppControlSize.row);
      expect(box.getMaxIntrinsicHeight(double.infinity), AppControlSize.row);
      expect(
        box.getDryLayout(const BoxConstraints(maxWidth: 30)),
        const Size(30, AppControlSize.row),
      );
    });

    testWidgets('a press outside the target misses', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Center(
          child: AppPressable(onTap: () => taps++, child: _dot),
        ),
      );
      await tester.tapAt(
        tester.getTopLeft(find.byType(AppPressable)) - const Offset(4, 4),
      );
      expect(taps, 0);
    });

    testWidgets('with a colour draws its own surface in its shape', (
      tester,
    ) async {
      await tester.pumpApp(
        Center(
          child: Column(
            children: [
              AppPressable(
                onTap: () {},
                color: AppColors.light.surface,
                shape: const StadiumBorder(),
                child: _dot,
              ),
              AppPressable(
                onTap: () {},
                color: AppColors.light.raised,
                child: _dot,
              ),
            ],
          ),
        ),
      );
      final surfaces = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(AppPressable),
              matching: find.byType(Material),
            ),
          )
          .toList();
      expect(surfaces.map((m) => m.color), [
        AppColors.light.surface,
        AppColors.light.raised,
      ]);
      expect(surfaces.map((m) => m.clipBehavior), [Clip.antiAlias, Clip.none]);
    });
  });

  group('AppPressable golden', () {
    goldenStates('app_pressable', [
      (
        'Icon, centred in its 44 pt target',
        Center(
          child: AppPressable(onTap: () {}, child: const Icon(AppSymbols.add)),
        ),
      ),
      (
        'Content on a card',
        AppCard(
          child: AppPressable(
            onTap: () {},
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.l),
              child: Text('Tap anywhere on the card'),
            ),
          ),
        ),
      ),
      (
        'Its own surface',
        Builder(
          builder: (context) => Center(
            child: AppPressable(
              onTap: () {},
              color: context.appColors.raised,
              shape: const RoundedSuperellipseBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.m)),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.l,
                  vertical: AppSpacing.xs,
                ),
                child: Text('Key'),
              ),
            ),
          ),
        ),
      ),
    ], width: 240);
  });
}
