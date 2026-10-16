import 'package:app_ui/app_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

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

  group('AppPageTransitionsTheme', () {
    testWidgets('puts every page in a column, as wide as its route allows', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(1366, 1024)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: AppTheme.light.copyWith(
            pageTransitionsTheme: const AppPageTransitionsTheme(
              maxWidths: {'today': AppContentWidth.dashboard},
            ),
          ),
          home: const Placeholder(),
        ),
      );
      expect(
        tester.getSize(find.byType(Placeholder)).width,
        AppContentWidth.readable,
      );

      navigator.currentState!.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'today'),
          builder: (_) => const SizedBox.expand(key: Key('today')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key('today'))).width,
        AppContentWidth.dashboard,
      );
    });
  });
}
