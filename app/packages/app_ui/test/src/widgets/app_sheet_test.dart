import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// A navigator whose second page, while open, is an [AppSheetPage].
class _Host extends StatefulWidget {
  const new({required this.size});

  final AppSheetSize size;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  var _open = false;

  @override
  Widget build(BuildContext context) => Navigator(
    pages: [
      MaterialPage<void>(
        child: Scaffold(
          body: TextButton(
            onPressed: () => setState(() => _open = true),
            child: const Text('Open'),
          ),
        ),
      ),
      if (_open)
        AppSheetPage<void>(
          size: widget.size,
          child: Scaffold(
            appBar: AppBar(title: const Text('Sheet')),
            body: ListView(
              children: [for (var i = 0; i < 40; i++) Text('Row $i')],
            ),
          ),
        ),
    ],
    onDidRemovePage: (_) => setState(() => _open = false),
  );
}

void main() {
  double screen(WidgetTester tester) =>
      tester.view.physicalSize.height / tester.view.devicePixelRatio;

  double sheetHeight(WidgetTester tester) =>
      tester.getSize(find.byType(BottomSheet)).height;

  Future<void> openPage(
    WidgetTester tester, {
    AppSheetSize size = AppSheetSize.half,
    double textScale = 1,
    ThemeData? theme,
  }) async {
    await tester.pumpApp(
      _Host(size: size),
      textScale: textScale,
      theme: theme,
      scaffold: false,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  group(AppSheetPage, () {
    testWidgets('opens a half sheet with a drag handle', (tester) async {
      await openPage(tester);
      expect(find.text('Sheet'), findsOneWidget);
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.showDragHandle, isTrue);
      expect(sheetHeight(tester), lessThan(screen(tester) * 0.65));
      expect(sheetHeight(tester), greaterThan(screen(tester) * 0.5));
    });

    testWidgets('its list drags it up to full height', (tester) async {
      await openPage(tester);
      final half = sheetHeight(tester);
      await tester.drag(find.text('Row 2'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(sheetHeight(tester), greaterThan(half));
    });

    testWidgets('opens at full height at large text sizes', (tester) async {
      await openPage(tester, textScale: 2);
      expect(sheetHeight(tester), greaterThan(screen(tester) * 0.8));
    });

    testWidgets('opens compact at about a third of the height', (tester) async {
      await openPage(tester, size: AppSheetSize.compact);
      // 35% plus the drag handle.
      expect(sheetHeight(tester), lessThan(screen(tester) * 0.45));
    });

    testWidgets('opens full at full height', (tester) async {
      await openPage(tester, size: AppSheetSize.full);
      expect(sheetHeight(tester), greaterThan(screen(tester) * 0.8));
    });

    testWidgets('is the canvas colour in dark mode, from the app theme', (
      tester,
    ) async {
      await openPage(tester, theme: AppTheme.dark);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, AppColors.dark.canvas);
    });

    testWidgets('closes when dragged down', (tester) async {
      await openPage(tester);
      await tester.fling(find.text('Sheet'), const Offset(0, 600), 2000);
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });
  });

  group('showAppSheet', () {
    testWidgets('returns what the sheet closes with', (tester) async {
      late Future<String?> result;
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showAppSheet<String>(
              context: context,
              size: AppSheetSize.compact,
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).pop('Chosen'),
                child: const Text('Choose'),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // 35% plus the drag handle.
      expect(sheetHeight(tester), lessThan(screen(tester) * 0.45));

      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      expect(await result, 'Chosen');
    });

    testWidgets('appears without animating under reduced motion', (
      tester,
    ) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppSheet<void>(
              context: context,
              builder: (_) => const Text('Sheet'),
            ),
            child: const Text('Open'),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      final top = tester.getTopLeft(find.byType(BottomSheet)).dy;
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(BottomSheet)).dy, top);
    });
  });

  group('AppSheetPage golden', () {
    Widget sheet(AppSheetSize size) => Navigator(
      pages: [
        const MaterialPage<void>(child: SizedBox.expand()),
        AppSheetPage<void>(
          size: size,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: AppSection(
              header: 'Log Weight',
              children: [
                AppListRow(
                  title: 'Weight',
                  accessory: AppListRowValue('81.4 kg'),
                ),
                AppListRow(title: 'Date', accessory: AppListRowValue('Today')),
              ],
            ),
          ),
        ),
      ],
      onDidRemovePage: (_) {},
    );
    goldenStates(
      'app_sheet',
      [
        ('Compact', sheet(AppSheetSize.compact)),
        ('Half', sheet(AppSheetSize.half)),
        ('Full', sheet(AppSheetSize.full)),
      ],
      width: 375,
      height: 560,
      padded: false,
    );
  });
}
