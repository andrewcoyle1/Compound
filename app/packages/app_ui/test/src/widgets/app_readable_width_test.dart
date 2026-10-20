import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void _goldenTap() {}

void main() {
  group('AppReadableWidth', () {
    void sizeView(WidgetTester tester, Size size, {EdgeInsets? padding}) {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      if (padding != null) {
        tester.view.padding = FakeViewPadding(
          left: padding.left,
          right: padding.right,
        );
      }
      addTearDown(tester.view.reset);
    }

    testWidgets('fills a phone', (tester) async {
      sizeView(tester, const Size(390, 844));
      await tester.pumpApp(
        const AppReadableWidth(child: Placeholder()),
        scaffold: false,
      );
      expect(tester.getSize(find.byType(Placeholder)).width, 390);
    });

    testWidgets('centres a readable column on an iPad', (tester) async {
      sizeView(tester, const Size(1024, 1366));
      await tester.pumpApp(
        const AppReadableWidth(child: Placeholder()),
        scaffold: false,
      );
      final rect = tester.getRect(find.byType(Placeholder));
      expect(rect.width, AppContentWidth.readable);
      expect(rect.center.dx, 512);
    });

    testWidgets('takes a wider maximum', (tester) async {
      sizeView(tester, const Size(1366, 1024));
      await tester.pumpApp(
        const AppReadableWidth(
          maxWidth: AppContentWidth.dashboard,
          child: Placeholder(),
        ),
        scaffold: false,
      );
      expect(
        tester.getSize(find.byType(Placeholder)).width,
        AppContentWidth.dashboard,
      );
    });

    testWidgets('keeps only the safe area the margin does not cover', (
      tester,
    ) async {
      // A phone on its side: 59 pt notch, 87 pt margins.
      sizeView(
        tester,
        const Size(874, 402),
        padding: const EdgeInsets.only(left: 59, right: 59),
      );
      late EdgeInsets padding;
      await tester.pumpApp(
        AppReadableWidth(
          maxWidth: 800,
          child: Builder(
            builder: (context) {
              padding = MediaQuery.paddingOf(context);
              return const SizedBox();
            },
          ),
        ),
        scaffold: false,
      );
      expect(padding.left, 22);
      expect(padding.right, 22);
    });
  });

  group('AppScaffold', () {
    testWidgets('spans the app bar across the window, the rest in a column', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1366, 1024)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        AppScaffold(
          appBar: AppBar(title: const Text('Title')),
          body: const SizedBox.expand(key: Key('body')),
          bottomNavigationBar: const SizedBox(height: 44, key: Key('cta')),
          backgroundColor: Colors.red,
        ),
        scaffold: false,
      );
      expect(tester.getSize(find.byType(AppBar)).width, 1366);
      expect(
        tester.getSize(find.byKey(const Key('body'))).width,
        AppContentWidth.readable,
      );
      expect(
        tester.getSize(find.byKey(const Key('cta'))).width,
        AppContentWidth.readable,
      );
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.red,
      );
    });

    testWidgets('takes a wider column, and leaves out what is not given', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1366, 1024)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpApp(
        const AppScaffold(
          maxWidth: AppContentWidth.dashboard,
          body: SizedBox.expand(key: Key('body')),
        ),
        scaffold: false,
      );
      expect(
        tester.getSize(find.byKey(const Key('body'))).width,
        AppContentWidth.dashboard,
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.appBar, isNull);
      expect(scaffold.bottomNavigationBar, isNull);
    });

    testWidgets('a large title scrolls up into the app bar', (tester) async {
      await tester.pumpApp(
        AppScaffold(
          largeTitle: 'Today',
          actions: const [Icon(AppSymbols.settings)],
          body: ListView(
            children: [for (var i = 0; i < 50; i++) Text('Row $i')],
          ),
          bottomNavigationBar: const SizedBox(height: 44, key: Key('cta')),
        ),
        scaffold: false,
      );
      double barTitleOpacity() => tester
          .widget<AnimatedOpacity>(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;
      expect(find.text('Today'), findsNWidgets(2));
      expect(barTitleOpacity(), 0);
      expect(find.byIcon(AppSymbols.settings), findsOneWidget);
      expect(find.byKey(const Key('cta')), findsOneWidget);

      await tester.drag(find.text('Row 5'), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(barTitleOpacity(), 1);
    });

    testWidgets('a large title stops growing at accessibility sizes', (
      tester,
    ) async {
      await tester.pumpApp(
        const AppScaffold(largeTitle: 'Today'),
        scaffold: false,
        textScale: 3,
      );
      final title = find.descendant(
        of: find.byType(NestedScrollView),
        matching: find.text('Today'),
      );
      expect(
        MediaQuery.textScalerOf(tester.element(title)).scale(10),
        10 * AppScaffold.largeTitleMaxTextScale,
      );
    });

    testWidgets('a large title stands without a body', (tester) async {
      await tester.pumpApp(
        const AppScaffold(largeTitle: 'Today'),
        scaffold: false,
      );
      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byType(NestedScrollView),
            matching: find.text('Today'),
          ),
        ),
        isSemantics(label: 'Today', isHeader: true),
      );
    });
  });

  group('AppScaffold golden', () {
    final body = ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      children: const [
        AppSection(
          header: 'Account',
          children: [
            AppListRow(title: 'Email', accessory: AppListRowValue('a@b.com')),
            AppListRow(title: 'Units', accessory: AppListRowMenu('Metric')),
          ],
        ),
      ],
    );
    goldenStates(
      'app_scaffold',
      [
        (
          'Modal: close and confirm',
          AppScaffold(
            appBar: AppBar(
              title: const Text('Edit Profile'),
              leading: const AppToolbarButton.close(semanticLabel: 'Close'),
              actions: const [
                AppToolbarButton.confirm(
                  semanticLabel: 'Save',
                  onPressed: _goldenTap,
                ),
              ],
            ),
            body: body,
          ),
        ),
        (
          'Tab root: large title',
          AppScaffold(
            largeTitle: 'Settings',
            actions: const [
              AppToolbarButton(
                icon: AppSymbols.add,
                semanticLabel: 'Add',
                onPressed: _goldenTap,
              ),
            ],
            body: body,
          ),
        ),
      ],
      width: 375,
      height: 360,
      padded: false,
    );
  });
}
