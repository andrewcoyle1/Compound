import 'package:app_ui/app_ui.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

String _kg(num value) => '${AppFormat.number(value, maxFractionDigits: 1)} kg';

AppMomentHero _hero({
  num value = 12450,
  AppMomentCelebration celebration = AppMomentCelebration.moment,
  String? badge = 'Workout Complete',
  String? caption = 'Push Day',
  Widget? info,
  List<AppMomentStat> stats = const [],
}) => AppMomentHero(
  value: value,
  format: _kg,
  label: 'Lifted',
  badge: badge,
  caption: caption,
  info: info,
  stats: stats,
  celebration: celebration,
);

void main() {
  late List<AppHaptic> haptics;

  setUp(() {
    haptics = [];
    AppHaptics.debugPlay = haptics.add;
  });

  tearDown(() => AppHaptics.debugPlay = null);

  group('AppMomentHero', () {
    testWidgets('counts up to its value, then plays success once', (
      tester,
    ) async {
      await tester.pumpApp(_hero(), disableAnimations: false);
      expect(find.text('0 kg'), findsOneWidget);
      expect(haptics, isEmpty);

      await tester.pump(AppMotion.emphasis.duration ~/ 2);
      expect(find.text('0 kg'), findsNothing);
      expect(find.text('12,450 kg'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('12,450 kg'), findsOneWidget);
      expect(haptics, [AppHaptic.success]);
    });

    testWidgets('counts on from the value shown, with no second haptic', (
      tester,
    ) async {
      await tester.pumpApp(_hero(value: 10), disableAnimations: false);
      await tester.pumpAndSettle();
      await tester.pumpApp(_hero(value: 20), disableAnimations: false);
      await tester.pump(AppMotion.emphasis.duration ~/ 2);
      expect(find.text('10 kg'), findsNothing);
      expect(find.text('20 kg'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('20 kg'), findsOneWidget);
      expect(haptics, [AppHaptic.success]);
    });

    testWidgets('shows a fractional value exactly once it lands', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppMomentHero(value: 102.5, format: _kg, label: 'Bench Press'),
        disableAnimations: false,
      );
      await tester.pumpAndSettle();
      expect(find.text('102.5 kg'), findsOneWidget);
    });

    testWidgets('with reduced motion, shows the final state and plays the '
        'haptic', (tester) async {
      await tester.pumpApp(_hero(celebration: AppMomentCelebration.confetti));
      expect(find.text('12,450 kg'), findsOneWidget);
      await tester.pump();
      expect(find.byType(ConfettiWidget), findsNothing);
      expect(haptics, [AppHaptic.success]);
    });

    testWidgets('bursts confetti for the big ones', (tester) async {
      await tester.pumpApp(
        _hero(celebration: AppMomentCelebration.confetti),
        disableAnimations: false,
      );
      await tester.pump();
      expect(find.byType(ConfettiWidget), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('only shows without a celebration', (tester) async {
      await tester.pumpApp(
        _hero(celebration: AppMomentCelebration.none),
        disableAnimations: false,
      );
      expect(find.text('12,450 kg'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(ConfettiWidget), findsNothing);
      expect(haptics, isEmpty);
    });

    testWidgets('reads as one element with the final value', (tester) async {
      await tester.pumpApp(_hero(), disableAnimations: false);
      expect(
        find.bySemanticsLabel('Workout Complete, 12,450 kg, Lifted, Push Day'),
        findsOneWidget,
      );
      expect(find.text('LIFTED'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('keeps its info button and stats as their own elements', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpApp(
        _hero(
          badge: null,
          caption: null,
          info: AppIconButton(
            icon: AppSymbols.info,
            semanticLabel: 'How',
            onPressed: () => taps++,
          ),
          stats: const [
            (value: '52:10', label: 'Duration'),
            (value: '18', label: 'Sets'),
          ],
        ),
      );
      expect(find.bySemanticsLabel('12,450 kg, Lifted'), findsOneWidget);
      expect(
        tester.getSemantics(
          find
              .ancestor(
                of: find.text('52:10'),
                matching: find.byType(Semantics),
              )
              .first,
        ),
        matchesSemantics(label: 'Duration', value: '52:10'),
      );
      expect(find.text('SETS'), findsOneWidget);
      await tester.tap(find.byTooltip('How'));
      expect(taps, 1);
    });
  });

  group('AppMomentHero golden', () {
    goldenStates('app_moment_hero', [
      (
        'badge, caption, stats',
        _hero(
          stats: const [
            (value: '52:10', label: 'Duration'),
            (value: '18', label: 'Sets'),
            (value: '3', label: 'PRs'),
          ],
        ),
      ),
      (
        'info, no badge',
        _hero(
          badge: null,
          celebration: AppMomentCelebration.none,
          info: AppIconButton(
            icon: AppSymbols.info,
            semanticLabel: 'How',
            onPressed: () {},
          ),
        ),
      ),
      (
        'a stat shrunk to fit',
        _hero(
          badge: null,
          caption: null,
          celebration: AppMomentCelebration.none,
          stats: const [
            (value: '15,013 kg', label: 'Volume'),
            (value: '+7%', label: 'vs Last Week'),
            (value: '8.1', label: 'Average RPE'),
          ],
        ),
      ),
      (
        'long value',
        const AppMomentHero(
          value: 1234567,
          format: _kg,
          label: 'Lifted this year',
          celebration: AppMomentCelebration.none,
        ),
      ),
    ]);
  });
}
