import 'dart:typed_data';

import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

// A 1×1 transparent PNG.
final _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void _goldenTap() {}

void main() {
  group('AppToolbarButton', () {
    testWidgets('a glyph is labelled, tappable and 44 pt', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Center(
          child: AppToolbarButton(
            icon: AppSymbols.add,
            semanticLabel: 'Add',
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(AppToolbarButton));
      expect(taps, 1);
      expect(find.byTooltip('Add'), findsOneWidget);
      expect(find.byIcon(AppSymbols.add), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppToolbarButton)).shortestSide,
        greaterThanOrEqualTo(AppControlSize.row),
      );
    });

    testWidgets('a glyph shows its badge count, none at zero', (tester) async {
      await tester.pumpApp(
        const Row(
          children: [
            AppToolbarButton(
              icon: AppSymbols.notifications,
              semanticLabel: 'Notifications',
              onPressed: _goldenTap,
              badgeCount: 3,
            ),
            AppToolbarButton(
              icon: AppSymbols.notifications,
              semanticLabel: 'Notifications',
              onPressed: _goldenTap,
            ),
          ],
        ),
      );
      expect(find.text('3'), findsOneWidget);
      final badges = tester.widgetList<Badge>(find.byType(Badge)).toList();
      expect(badges.map((badge) => badge.isLabelVisible), [true, false]);
    });

    testWidgets('close pops the route by default', (tester) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: AppToolbarButton.close(semanticLabel: 'Close'),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byIcon(AppSymbols.close), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byIcon(AppSymbols.close), findsNothing);
    });

    testWidgets('close calls its own onPressed', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        AppToolbarButton.close(semanticLabel: 'Close', onPressed: () => taps++),
      );
      await tester.tap(find.byType(AppToolbarButton));
      expect(taps, 1);
    });

    testWidgets('confirm is a tick that can be tapped', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        Center(
          child: AppToolbarButton.confirm(
            semanticLabel: 'Save',
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(AppToolbarButton));
      expect(taps, 1);
      expect(find.byIcon(AppSymbols.confirm), findsOneWidget);
      expect(
        tester.getSize(find.byType(AppToolbarButton)).shortestSide,
        greaterThanOrEqualTo(AppControlSize.row),
      );
    });

    testWidgets('confirm spins and is disabled while saving', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        AppToolbarButton.confirm(
          semanticLabel: 'Save',
          onPressed: () => taps++,
          isSaving: true,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(AppSymbols.confirm), findsNothing);
      await tester.tap(find.byType(AppToolbarButton));
      expect(taps, 0);
    });

    testWidgets('avatar shows the photo', (tester) async {
      await tester.pumpApp(
        AppToolbarButton.avatar(
          semanticLabel: 'Profile',
          onPressed: () {},
          image: MemoryImage(_pixel),
          initials: 'AC',
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(find.byTooltip('Profile'), findsOneWidget);
    });

    testWidgets('avatar falls back when the photo fails', (tester) async {
      await tester.pumpApp(
        AppToolbarButton.avatar(
          semanticLabel: 'Profile',
          onPressed: () {},
          image: MemoryImage(Uint8List.fromList([0, 1, 2])),
          initials: 'AC',
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('AC'), findsOneWidget);
    });

    testWidgets('avatar shows initials without a photo', (tester) async {
      await tester.pumpApp(
        AppToolbarButton.avatar(
          semanticLabel: 'Profile',
          onPressed: () {},
          initials: 'AC',
        ),
      );
      expect(find.text('AC'), findsOneWidget);
    });

    for (final initials in [null, '']) {
      testWidgets('avatar shows the glyph with initials $initials', (
        tester,
      ) async {
        await tester.pumpApp(
          AppToolbarButton.avatar(
            semanticLabel: 'Profile',
            onPressed: () {},
            initials: initials,
          ),
        );
        expect(find.byIcon(AppSymbols.profile), findsOneWidget);
      });
    }
  });

  group('AppToolbarButton golden', () {
    goldenStates(
      'app_toolbar_button',
      [
        (
          'Glyph, close',
          const Row(
            children: [
              AppToolbarButton(
                icon: AppSymbols.add,
                semanticLabel: 'Add',
                onPressed: _goldenTap,
              ),
              AppToolbarButton.close(
                semanticLabel: 'Close',
                onPressed: _goldenTap,
              ),
            ],
          ),
        ),
        (
          'Glyph with a badge',
          const Row(
            children: [
              AppToolbarButton(
                icon: AppSymbols.notifications,
                semanticLabel: 'Notifications',
                onPressed: _goldenTap,
                badgeCount: 3,
              ),
              AppToolbarButton(
                icon: AppSymbols.notifications,
                semanticLabel: 'Notifications',
                onPressed: _goldenTap,
                badgeCount: 12,
              ),
            ],
          ),
        ),
        (
          'Confirm: enabled, disabled, saving',
          const Row(
            children: [
              AppToolbarButton.confirm(
                semanticLabel: 'Save',
                onPressed: _goldenTap,
              ),
              AppToolbarButton.confirm(semanticLabel: 'Save', onPressed: null),
              AppToolbarButton.confirm(
                semanticLabel: 'Save',
                onPressed: _goldenTap,
                isSaving: true,
              ),
            ],
          ),
        ),
        (
          'Avatar: initials, none',
          const Row(
            children: [
              AppToolbarButton.avatar(
                semanticLabel: 'Profile',
                onPressed: _goldenTap,
                initials: 'AC',
              ),
              AppToolbarButton.avatar(
                semanticLabel: 'Profile',
                onPressed: _goldenTap,
              ),
            ],
          ),
        ),
      ],
      width: 220,
      pumpBeforeTest: pumpOnceSettled,
    );
  });
}
