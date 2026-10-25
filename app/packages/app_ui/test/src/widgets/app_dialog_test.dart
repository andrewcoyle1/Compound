import 'package:app_ui/app_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoAlertDialog, CupertinoDialogAction;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  const colors = AppColors.light;

  ThemeData on(TargetPlatform platform) =>
      AppTheme.light.copyWith(platform: platform);

  /// Pumps a button that runs [open], taps it and returns its future.
  Future<({Future<T> result})> open<T>(
    WidgetTester tester,
    TargetPlatform platform,
    Future<T> Function(BuildContext context) open,
  ) async {
    late Future<T> result;
    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => result = open(context),
          child: const Text('Open'),
        ),
      ),
      theme: on(platform),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return (result: result);
  }

  group('AppDialog.confirmDestructive', () {
    Future<bool> Function(BuildContext) confirm({String? cancelLabel}) =>
        (context) => AppDialog.confirmDestructive(
          context,
          title: 'Delete this workout?',
          message: 'This cannot be undone.',
          confirmLabel: 'Delete',
          cancelLabel: cancelLabel,
        );

    testWidgets('is an iOS alert on iOS: Cancel bold, Delete in danger', (
      tester,
    ) async {
      final (:result) = await open(tester, TargetPlatform.iOS, confirm());
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);
      final actions = tester
          .widgetList<CupertinoDialogAction>(find.byType(CupertinoDialogAction))
          .toList();
      expect(actions.first.isDefaultAction, isTrue);
      expect(actions.first.textStyle?.color, colors.accentInk);
      expect(actions.last.isDestructiveAction, isTrue);
      expect(actions.last.textStyle?.color, colors.danger);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });

    testWidgets('is a Material dialog elsewhere, Delete in danger', (
      tester,
    ) async {
      final (:result) = await open(tester, TargetPlatform.android, confirm());
      expect(find.byType(AlertDialog), findsOneWidget);
      final delete = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Delete'),
      );
      expect(delete.style?.foregroundColor?.resolve(const {}), colors.danger);
      final cancel = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancel'),
      );
      expect(
        cancel.style?.foregroundColor?.resolve(const {}),
        colors.accentInk,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('a tap outside answers no', (tester) async {
      final (:result) = await open(
        tester,
        TargetPlatform.android,
        confirm(cancelLabel: 'Keep'),
      );
      expect(find.text('Keep'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await result, isFalse);
    });
  });

  group('showAppDialog', () {
    const actions = [
      AppDialogAction<int>(label: 'Cancel', role: AppDialogRole.cancel),
      AppDialogAction(label: 'Push Day', value: 1),
      AppDialogAction(label: 'Run', value: 2, role: AppDialogRole.preferred),
    ];

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('moves Cancel last when the actions stack on '
          '${platform.name}', (tester) async {
        final (:result) = await open(
          tester,
          platform,
          (context) => showAppDialog<int>(
            context: context,
            title: 'Which workout?',
            actions: actions,
          ),
        );
        final labels = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(AppDialog<int>),
                matching: find.byType(Text),
              ),
            )
            .map((text) => text.data)
            .toList();
        expect(labels, ['Which workout?', 'Push Day', 'Run', 'Cancel']);

        await tester.tap(find.text('Push Day'));
        await tester.pumpAndSettle();
        expect(await result, 1);
      });
    }

    testWidgets('on iOS a preferred action is bold and Cancel is not', (
      tester,
    ) async {
      await open(
        tester,
        TargetPlatform.iOS,
        (context) => showAppDialog<int>(
          context: context,
          title: 'Which workout?',
          actions: actions,
        ),
      );
      final bold = {
        for (final action in tester.widgetList<CupertinoDialogAction>(
          find.byType(CupertinoDialogAction),
        ))
          (action.child as Text).data: action.isDefaultAction,
      };
      expect(bold, {'Push Day': false, 'Run': true, 'Cancel': false});
    });

    testWidgets('on Android a preferred action is bold', (tester) async {
      await open(
        tester,
        TargetPlatform.android,
        (context) => showAppDialog<int>(
          context: context,
          title: 'Which workout?',
          actions: actions,
        ),
      );
      FontWeight? weight(String label) => tester
          .widget<TextButton>(find.widgetWithText(TextButton, label))
          .style
          ?.textStyle
          ?.resolve(const {})
          ?.fontWeight;
      expect(weight('Run'), FontWeight.w600);
      expect(weight('Push Day'), isNot(FontWeight.w600));
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('holds a text field read by its own action on '
          '${platform.name}', (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        final (:result) = await open(
          tester,
          platform,
          (context) => showAppDialog<String>(
            context: context,
            title: 'Enter Barcode',
            content: TextField(controller: controller),
            actions: [
              const AppDialogAction(
                label: 'Cancel',
                role: AppDialogRole.cancel,
              ),
              AppDialogAction(
                label: 'Look Up',
                role: AppDialogRole.preferred,
                onPressed: () =>
                    Navigator.of(tester.element(find.byType(TextField)))
                        .pop(controller.text),
              ),
            ],
          ),
        );
        await tester.enterText(find.byType(TextField), '4006381333931');
        await tester.tap(find.text('Look Up'));
        await tester.pumpAndSettle();
        expect(await result, '4006381333931');
      });

      testWidgets('has no content with only a title on ${platform.name}', (
        tester,
      ) async {
        final (:result) = await open(
          tester,
          platform,
          (context) => showAppDialog<void>(
            context: context,
            title: "You're offline",
            actions: const [AppDialogAction(label: 'OK')],
          ),
        );
        expect(find.text("You're offline"), findsOneWidget);
        // The dialog's own content column, spaced, is left out.
        expect(
          find.byWidgetPredicate((w) => w is Column && w.spacing > 0),
          findsNothing,
        );
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await result;
        expect(find.text("You're offline"), findsNothing);
      });
    }
  });

  group('AppDialog golden', () {
    const twoActions = AppDialog<bool>(
      title: 'Discard changes?',
      message: 'Your edits to this workout will be lost.',
      actions: [
        AppDialogAction(label: 'Cancel', role: AppDialogRole.cancel),
        AppDialogAction(label: 'Keep Editing', role: AppDialogRole.preferred),
      ],
    );
    const destructive = AppDialog<bool>(
      title: 'Delete workout?',
      message: 'This cannot be undone.',
      actions: [
        AppDialogAction(label: 'Cancel', role: AppDialogRole.cancel),
        AppDialogAction(label: 'Delete', role: AppDialogRole.destructive),
      ],
    );
    const threeActions = AppDialog<int>(
      title: 'Save as template?',
      actions: [
        AppDialogAction(label: 'Cancel', role: AppDialogRole.cancel),
        AppDialogAction(label: 'Save', role: AppDialogRole.preferred),
        AppDialogAction(label: 'Save as Copy'),
      ],
    );
    const withContent = AppDialog<void>(
      title: 'Rename',
      content: TextField(decoration: InputDecoration(hintText: 'Name')),
      actions: [
        AppDialogAction(label: 'Cancel', role: AppDialogRole.cancel),
        AppDialogAction(label: 'Save', role: AppDialogRole.preferred),
      ],
    );
    goldenStates(
      'app_dialog',
      [
        ('Two actions', twoActions),
        ('Destructive', destructive),
        ('Three actions stack', threeActions),
        ('With a field', withContent),
        ('Two actions, iOS', onIos(twoActions)),
        ('Destructive, iOS', onIos(destructive)),
        ('Three actions stack, iOS', onIos(threeActions)),
        ('With a field, iOS', onIos(withContent)),
      ],
      width: 390,
      height: 340,
      padded: false,
    );
  });
}
