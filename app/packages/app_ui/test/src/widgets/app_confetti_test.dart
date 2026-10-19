import 'package:app_ui/app_ui.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppConfetti', () {
    final burst = find.byType(ConfettiWidget);

    testWidgets('shows only its child at rest', (tester) async {
      await tester.pumpApp(const AppConfetti(child: glyph));
      expect(find.byIcon(AppSymbols.success), findsOneWidget);
      expect(burst, findsNothing);
    });

    testWidgets('bursts when play turns true, then clears and settles', (
      tester,
    ) async {
      await tester.pumpApp(const AppConfetti(child: glyph));
      await tester.pumpApp(const AppConfetti(play: true, child: glyph));
      await tester.pump();
      expect(burst, findsOneWidget);
      expect(
        find.ancestor(of: burst, matching: find.byType(IgnorePointer)),
        findsWidgets,
      );

      // Staying true does not burst again.
      await tester.pump(AppConfetti.lifetime);
      await tester.pumpApp(const AppConfetti(play: true, child: glyph));
      await tester.pumpAndSettle();
      expect(burst, findsNothing);
      expect(find.byIcon(AppSymbols.success), findsOneWidget);
    });

    testWidgets('bursts once when it appears, if asked', (tester) async {
      await tester.pumpApp(const AppConfetti(playsOnMount: true, child: glyph));
      await tester.pump();
      expect(burst, findsOneWidget);
      await tester.pumpAndSettle();
      expect(burst, findsNothing);
    });

    testWidgets('bursts again from the start while still bursting', (
      tester,
    ) async {
      await tester.pumpApp(const AppConfetti(playsOnMount: true, child: glyph));
      await tester.pump(AppConfetti.lifetime ~/ 2);
      await tester.pumpApp(const AppConfetti(child: glyph));
      await tester.pumpApp(const AppConfetti(play: true, child: glyph));
      await tester.pump(AppConfetti.lifetime * 0.75);
      expect(burst, findsOneWidget);
      await tester.pumpAndSettle();
      expect(burst, findsNothing);
    });

    testWidgets('never plays with reduced motion', (tester) async {
      await tester.pumpApp(
        const AppConfetti(playsOnMount: true, child: glyph),
        disableAnimations: true,
      );
      await tester.pump();
      expect(burst, findsNothing);
    });

    testWidgets('never plays without an overlay to draw in', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AppConfetti(playsOnMount: true, child: glyph),
        ),
      );
      await tester.pump();
      expect(burst, findsNothing);
    });

    testWidgets('takes no taps from what is under it', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Center(
          child: AppConfetti(
            playsOnMount: true,
            child: AppCtaButton(label: 'Done', onPressed: () => taps++),
          ),
        ),
      );
      await tester.pump();
      expect(burst, findsOneWidget);
      await tester.tap(find.text('Done'));
      expect(taps, 1);
    });

    testWidgets('can go mid-burst', (tester) async {
      await tester.pumpApp(const AppConfetti(playsOnMount: true, child: glyph));
      await tester.pump();
      await tester.pumpApp(const SizedBox.shrink());
      expect(burst, findsNothing);
    });
  });

  group('AppConfetti golden', () {
    goldenStates('app_confetti', [
      ('At rest', const AppConfetti(child: glyph)),
      (
        'After a burst',
        const _Overlaid(AppConfetti(playsOnMount: true, child: glyph)),
      ),
    ]);
  });
}

const glyph = Icon(AppSymbols.success);

/// [child] in an overlay of its own, as a screen would have.
class _Overlaid extends StatefulWidget {
  const new(this.child);

  final Widget child;

  @override
  State<_Overlaid> createState() => _OverlaidState();
}

class _OverlaidState extends State<_Overlaid> {
  late final _entry = OverlayEntry(builder: (_) => Center(child: widget.child));

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppControlSize.row,
    child: Overlay(initialEntries: [_entry]),
  );
}
