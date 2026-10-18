import 'package:compound/widgets/half_sheet_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> open(WidgetTester tester, {double textScale = 1}) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => TextButton(
            onPressed: () => context.push('/sheet'),
            child: const Text('Open'),
          ),
        ),
        GoRoute(
          path: '/sheet',
          pageBuilder: (_, state) => HalfSheetPage(
            key: state.pageKey,
            child: Scaffold(
              appBar: AppBar(title: const Text('Sheet')),
              body: ListView(
                children: [
                  for (var i = 0; i < 40; i++) ListTile(title: Text('Row $i')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  double sheetHeight(WidgetTester tester) =>
      tester.getSize(find.byType(Scaffold).last).height;

  testWidgets('opens at half height with a drag handle', (tester) async {
    await open(tester);
    expect(find.text('Sheet'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(sheetHeight(tester), lessThan(screen * 0.6));
  });

  testWidgets('its list drags it up to full height', (tester) async {
    await open(tester);
    final half = sheetHeight(tester);
    await tester.drag(find.text('Row 2'), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(sheetHeight(tester), greaterThan(half));
  });

  testWidgets('opens at full height at large text sizes', (tester) async {
    await open(tester, textScale: 2);
    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(sheetHeight(tester), greaterThan(screen * 0.8));
  });
}
