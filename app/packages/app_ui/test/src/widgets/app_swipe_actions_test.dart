import 'package:app_ui/app_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AppSwipeActions', () {
    late List<String> ran;
    late int rowTaps;
    late int haptics;

    setUp(() {
      ran = [];
      rowTaps = 0;
      haptics = 0;
    });

    AppSwipeAction action(
      String label, {
      IconData? icon,
      Color? tint,
      bool isDestructive = false,
    }) => AppSwipeAction(
      label: label,
      icon: icon,
      tint: tint,
      isDestructive: isDestructive,
      onPressed: () => ran.add(label),
    );

    Future<void> pump(
      WidgetTester tester, {
      List<AppSwipeAction>? leading,
      List<AppSwipeAction>? trailing,
      bool leadingFullSwipe = true,
      bool trailingFullSwipe = true,
      TextDirection direction = TextDirection.ltr,
    }) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics++;
          return null;
        },
      );
      await tester.pumpApp(
        Directionality(
          textDirection: direction,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 400,
              child: AppSwipeActions(
                leading:
                    leading ?? [action('Log Again', icon: AppSymbols.logAgain)],
                trailing:
                    trailing ??
                    [
                      action(
                        'Delete',
                        icon: AppSymbols.delete,
                        isDestructive: true,
                      ),
                      action('Edit', icon: AppSymbols.edit),
                    ],
                leadingFullSwipe: leadingFullSwipe,
                trailingFullSwipe: trailingFullSwipe,
                child: InkWell(
                  onTap: () => rowTaps++,
                  child: const SizedBox(height: 56, child: Text('Oats')),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // How far the row has moved, in logical pixels from its place.
    double rowShift(WidgetTester tester) => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(AppSwipeActions),
            matching: find.byType(Transform),
          ),
        )
        .transform
        .getTranslation()
        .x;

    // A quick swipe by [dx]: five steps 5 ms apart.
    Future<void> flick(WidgetTester tester, double dx) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppSwipeActions)),
      );
      for (var step = 1; step <= 5; step++) {
        await gesture.moveBy(
          Offset(dx / 5, 0),
          timeStamp: Duration(milliseconds: step * 5),
        );
      }
      await gesture.up(timeStamp: const Duration(milliseconds: 30));
      await tester.pumpAndSettle();
    }

    testWidgets('shows only the row until swiped', (tester) async {
      await pump(tester);
      expect(find.byIcon(AppSymbols.delete), findsNothing);
      await tester.tap(find.text('Oats'));
      expect(rowTaps, 1);
    });

    testWidgets('a swipe to the start reveals the trailing buttons, the '
        'first at the edge, and a tap runs one and closes', (tester) async {
      await pump(tester);
      await tester.drag(find.byType(AppSwipeActions), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(rowShift(tester), -2 * AppSwipeActions.buttonWidth);
      final delete = tester.getCenter(find.byIcon(AppSymbols.delete));
      final edit = tester.getCenter(find.byIcon(AppSymbols.edit));
      expect(delete.dx, greaterThan(edit.dx));
      await tester.tap(find.byIcon(AppSymbols.edit));
      await tester.pumpAndSettle();
      expect(ran, ['Edit']);
      expect(rowShift(tester), 0);
      expect(find.byIcon(AppSymbols.edit), findsNothing);
    });

    testWidgets('a tap on the open row only closes it', (tester) async {
      await pump(tester);
      await tester.drag(find.byType(AppSwipeActions), const Offset(100, 0));
      await tester.pumpAndSettle();
      expect(rowShift(tester), AppSwipeActions.buttonWidth);
      // The row is covered while open, so the tap lands on the cover.
      await tester.tap(find.text('Oats'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(rowTaps, 0);
      expect(rowShift(tester), 0);
    });

    testWidgets('a short swipe closes again, a quick one opens or closes', (
      tester,
    ) async {
      await pump(tester);
      await tester.drag(find.byType(AppSwipeActions), const Offset(-40, 0));
      await tester.pumpAndSettle();
      expect(rowShift(tester), 0);
      await flick(tester, -60);
      expect(rowShift(tester), -2 * AppSwipeActions.buttonWidth);
      await flick(tester, 60);
      expect(rowShift(tester), 0);
    });

    testWidgets('a full swipe runs the first button, with a haptic', (
      tester,
    ) async {
      await pump(tester);
      await tester.drag(find.byType(AppSwipeActions), const Offset(-350, 0));
      await tester.pumpAndSettle();
      expect(ran, ['Delete']);
      expect(haptics, 1);
      expect(rowShift(tester), 0);
    });

    testWidgets('swiping back before letting go runs nothing', (tester) async {
      await pump(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppSwipeActions)),
      );
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(const Offset(-330, 0));
      await tester.pump();
      expect(haptics, 1);
      await gesture.moveBy(const Offset(200, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(ran, isEmpty);
      expect(haptics, 2);
    });

    testWidgets('without a full swipe the row stops at its buttons', (
      tester,
    ) async {
      await pump(tester, leadingFullSwipe: false);
      await tester.drag(find.byType(AppSwipeActions), const Offset(350, 0));
      await tester.pumpAndSettle();
      expect(ran, isEmpty);
      expect(rowShift(tester), AppSwipeActions.buttonWidth);
    });

    testWidgets('a side with no buttons does not move', (tester) async {
      await pump(tester, leading: const []);
      await tester.drag(find.byType(AppSwipeActions), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(rowShift(tester), 0);
      await tester.drag(find.byType(AppSwipeActions), const Offset(-120, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(AppSwipeActions), const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(rowShift(tester), 0);
    });

    testWidgets('a side with no buttons does not move, trailing', (
      tester,
    ) async {
      await pump(tester, trailing: const []);
      await tester.drag(find.byType(AppSwipeActions), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(rowShift(tester), 0);
    });

    testWidgets('in a right-to-left language the sides swap', (tester) async {
      await pump(tester, direction: TextDirection.rtl);
      await tester.drag(find.byType(AppSwipeActions), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(find.byIcon(AppSymbols.logAgain), findsOneWidget);
      expect(rowShift(tester), -AppSwipeActions.buttonWidth);
    });

    testWidgets('a button without an icon shows its label, in its tint', (
      tester,
    ) async {
      await pump(
        tester,
        leading: [
          action('Pin', tint: const Color(0xFFFFFFFF)),
          action('Mute'),
        ],
      );
      await tester.drag(find.byType(AppSwipeActions), const Offset(160, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Pin')).style!.color,
        const Color(0xFF000000),
      );
      expect(
        tester.widget<Text>(find.text('Mute')).style!.color,
        const Color(0xFFFFFFFF),
      );
      expect(
        tester.getCenter(find.text('Pin')).dx,
        lessThan(tester.getCenter(find.text('Mute')).dx),
      );
    });

    testWidgets('every button is a screen-reader action', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      final node = tester.getSemantics(find.byType(AppSwipeActions));
      final owner = tester.binding.renderViews.first.owner!.semanticsOwner!;
      for (final label in ['Log Again', 'Delete', 'Edit']) {
        owner.performAction(
          node.id,
          SemanticsAction.customAction,
          CustomSemanticsAction.getIdentifier(
            CustomSemanticsAction(label: label),
          ),
        );
      }
      expect(ran, ['Log Again', 'Delete', 'Edit']);
      handle.dispose();
    });
  });

  group('AppSwipeActions golden', () {
    const trailingOpen = Key('trailing open');
    const leadingOpen = Key('leading open');
    Widget row({Key? key}) => AppCard(
      child: AppSwipeActions(
        key: key,
        leading: [
          AppSwipeAction(
            label: 'Pin',
            icon: AppSymbols.pinnedNote,
            onPressed: () {},
          ),
        ],
        trailing: [
          AppSwipeAction(
            label: 'Delete',
            icon: AppSymbols.delete,
            isDestructive: true,
            onPressed: () {},
          ),
          AppSwipeAction(label: 'Edit', onPressed: () {}),
        ],
        child: const AppListRow(title: 'Upper A', subtitle: 'Yesterday'),
      ),
    );
    goldenStates(
      'app_swipe_actions',
      [
        ('Closed', row()),
        ('Trailing actions open', row(key: trailingOpen)),
        ('Leading action open', row(key: leadingOpen)),
      ],
      pumpBeforeTest: (tester) async {
        // Room for every cell, so each drag lands on its row.
        tester.view.physicalSize = const Size(2000, 2000);
        await tester.pumpAndSettle();
        for (final (key, dx) in [(trailingOpen, -120.0), (leadingOpen, 60.0)]) {
          final rows = find.byKey(key);
          for (var i = 0; i < rows.evaluate().length; i++) {
            // On the title: the row's middle falls between its two lines,
            // which nothing there hit-tests.
            await tester.dragFrom(
              tester.getTopLeft(rows.at(i)) + const Offset(24, 20),
              Offset(dx, 0),
            );
          }
        }
        await tester.pumpAndSettle();
      },
    );
  });
}
