import 'package:app_ui/app_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// What a scope reported, in order: `shown:<id>` and `dismissed:<id>`.
final List<String> _log = [];

AppTipScope _scope(
  Widget child, {
  List<String> tips = const ['hold', 'swipe'],
  Set<String> seen = const {},
}) => AppTipScope(
  tips: tips,
  isSeen: seen.contains,
  onShown: (id) => _log.add('shown:$id'),
  onDismissed: (id) => _log.add('dismissed:$id'),
  dismissLabel: 'Got It',
  child: child,
);

AppTip _tip(String id, {String? label}) => AppTip(
  id: id,
  title: 'Title $id',
  message: 'Message $id',
  child: SizedBox(height: 60, child: Text(label ?? 'Target $id')),
);

void main() {
  setUp(_log.clear);

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(AppTipScope.settle);
    await tester.pumpAndSettle();
  }

  testWidgets('without a scope, a tip is only its child', (tester) async {
    await tester.pumpApp(_tip('hold'));
    await settle(tester);
    expect(find.text('Target hold'), findsOneWidget);
    expect(find.byType(AppTipCallout), findsNothing);
  });

  testWidgets('shows the first new tip once the screen settles, and Got '
      'It closes it', (tester) async {
    await tester.pumpApp(
      _scope(Column(children: [_tip('swipe'), _tip('hold')])),
    );
    await tester.pump();
    expect(find.byType(AppTipCallout), findsNothing);

    await settle(tester);
    expect(find.text('Title hold'), findsOneWidget);
    expect(find.text('Message hold'), findsOneWidget);
    expect(_log, ['shown:hold']);

    await tester.tap(find.text('Got It'));
    await tester.pumpAndSettle();
    expect(find.byType(AppTipCallout), findsNothing);
    expect(_log, ['shown:hold', 'dismissed:hold']);
  });

  testWidgets('skips a tip already seen', (tester) async {
    await tester.pumpApp(
      _scope(Column(children: [_tip('hold'), _tip('swipe')]), seen: {'hold'}),
    );
    await settle(tester);
    expect(find.text('Title swipe'), findsOneWidget);
    expect(_log, ['shown:swipe']);
  });

  testWidgets('shows nothing when every tip is seen', (tester) async {
    await tester.pumpApp(
      _scope(Column(children: [_tip('hold')]), seen: {'hold', 'swipe'}),
    );
    await settle(tester);
    expect(find.byType(AppTipCallout), findsNothing);
    expect(_log, isEmpty);
  });

  testWidgets('a tap anywhere closes it, and no second tip shows on the '
      'same visit', (tester) async {
    await tester.pumpApp(
      _scope(
        ListView(
          children: [_tip('hold'), _tip('swipe'), const SizedBox(height: 2000)],
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Title hold'), findsOneWidget);

    await tester.tapAt(const Offset(400, 590));
    await tester.pumpAndSettle();
    expect(find.byType(AppTipCallout), findsNothing);
    expect(_log, ['shown:hold', 'dismissed:hold']);

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await settle(tester);
    expect(find.byType(AppTipCallout), findsNothing);
    expect(_log, ['shown:hold', 'dismissed:hold']);
  });

  testWidgets('waits for its target to scroll wholly on screen', (
    tester,
  ) async {
    await tester.pumpApp(
      _scope(
        ListView(
          children: [
            const SizedBox(height: 580),
            _tip('hold'),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    await settle(tester);
    expect(find.byType(AppTipCallout), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(find.text('Title hold'), findsOneWidget);
  });

  testWidgets('of several targets with one id, picks the topmost', (
    tester,
  ) async {
    await tester.pumpApp(
      _scope(
        Column(
          children: [
            _tip('swipe', label: 'Row 1'),
            _tip('hold', label: 'Row 2'),
            _tip('hold', label: 'Row 3'),
          ],
        ),
        tips: ['hold'],
      ),
    );
    await settle(tester);
    expect(find.text('Title hold'), findsOneWidget);
    // The callout sits beside the row it is about.
    final callout = tester.getRect(find.byType(AppTipCallout));
    final row = tester.getRect(find.text('Row 2'));
    expect(
      (callout.top - row.bottom).abs() < 40 ||
          (row.top - callout.bottom).abs() < 40,
      isTrue,
    );
  });

  testWidgets('shows nothing while another route covers the screen', (
    tester,
  ) async {
    await tester.pumpApp(_scope(_tip('hold')));
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute<void>(builder: (_) => const Text('Other')));
    await settle(tester);
    expect(find.byType(AppTipCallout), findsNothing);
  });

  testWidgets('closes when another route is pushed over it', (tester) async {
    await tester.pumpApp(_scope(_tip('hold')));
    await settle(tester);
    expect(find.byType(AppTipCallout), findsOneWidget);

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute<void>(builder: (_) => const Text('Other')));
    await tester.pumpAndSettle();
    expect(find.byType(AppTipCallout), findsNothing);
    expect(_log, ['shown:hold', 'dismissed:hold']);
  });

  testWidgets('closes when its target goes', (tester) async {
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    await tester.pumpApp(
      _scope(
        ValueListenableBuilder(
          valueListenable: show,
          builder: (_, shown, _) => shown ? _tip('hold') : const SizedBox(),
        ),
      ),
    );
    await settle(tester);
    expect(find.byType(AppTipCallout), findsOneWidget);

    show.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(AppTipCallout), findsNothing);
    expect(_log, ['shown:hold', 'dismissed:hold']);
  });

  testWidgets('closes when its screen goes', (tester) async {
    await tester.pumpApp(_scope(_tip('hold')));
    await settle(tester);
    expect(find.byType(AppTipCallout), findsOneWidget);

    await tester.pumpApp(const SizedBox());
    await tester.pumpAndSettle();
    expect(find.byType(AppTipCallout), findsNothing);
    expect(_log, ['shown:hold', 'dismissed:hold']);
  });

  testWidgets('a screen reader reads its title as a heading and can close '
      'it', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpApp(
      _scope(Column(children: [_tip('hold'), const Text('Beneath')])),
    );
    await settle(tester);

    expect(
      tester.getSemantics(find.text('Title hold')),
      matchesSemantics(label: 'Title hold', isHeader: true, namesRoute: true),
    );
    // What is beneath is hidden from the reader while the tip shows.
    expect(find.semantics.byLabel('Beneath'), findsNothing);

    tester.semantics.dismiss(find.semantics.byAction(SemanticsAction.dismiss));
    await tester.pumpAndSettle();
    expect(find.byType(AppTipCallout), findsNothing);
    expect(_log, ['shown:hold', 'dismissed:hold']);
    semantics.dispose();
  });

  testWidgets('a callout repaints its notch for a new target', (tester) async {
    Widget callout(Rect target) => AppTipCallout(
      title: 'Title',
      message: 'Message',
      dismissLabel: 'Got It',
      onDismiss: () {},
      target: () => target,
    );
    await tester.pumpApp(callout(const Rect.fromLTWH(0, 0, 10, 10)));
    await tester.pumpApp(callout(const Rect.fromLTWH(100, 500, 10, 10)));
    expect(find.text('Title'), findsOneWidget);
  });

  group('AppTipCallout golden', () {
    goldenStates('app_tip_callout', [
      (
        'Short',
        AppTipCallout(
          title: 'Read the chart',
          message: 'Touch and hold for a day’s value. Pinch to zoom in.',
          dismissLabel: 'Got It',
          onDismiss: () {},
        ),
      ),
      ('Notch up', const _Pointing(calloutBelow: true)),
      ('Notch down', const _Pointing(calloutBelow: false)),
      (
        'Long',
        AppTipCallout(
          title: 'Log a meal again',
          message:
              'Swipe a food to the right to log its meal again now, or to '
              'the left to delete it.',
          dismissLabel: 'Got It',
          onDismiss: () {},
        ),
      ),
    ]);
  });
}

/// A callout beside a small target, its notch pointing at it.
class _Pointing extends StatefulWidget {
  const new({required this.calloutBelow});

  final bool calloutBelow;

  @override
  State<_Pointing> createState() => _PointingState();
}

class _PointingState extends State<_Pointing> {
  final GlobalKey _target = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final target = Align(
      alignment: const Alignment(-0.6, 0),
      child: Container(
        key: _target,
        width: 64,
        height: 28,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
    final callout = AppTipCallout(
      title: 'Rest for one set',
      message: 'Swipe a set right to give it its own rest time.',
      dismissLabel: 'Got It',
      onDismiss: () {},
      target: () {
        final box = _target.currentContext!.findRenderObject()! as RenderBox;
        return box.localToGlobal(Offset.zero) & box.size;
      },
    );
    return Column(
      spacing: AppSpacing.m,
      children: widget.calloutBelow ? [target, callout] : [callout, target],
    );
  }
}
