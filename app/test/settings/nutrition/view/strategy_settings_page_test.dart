import 'package:compound/app/app.dart';
import 'package:compound/settings/nutrition/view/strategy_settings_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/helpers.dart';
import '../helpers.dart';

void main() {
  late SpyCheckInRepository repository;

  setUp(() => repository = SpyCheckInRepository());

  Future<void> pump(WidgetTester tester) async {
    useTallView(tester);
    await tester.pumpApp(
      const StrategySettingsPage(),
      appBloc: signedInAppBloc(),
      checkInRepository: repository,
    );
    await tester.pumpAndSettle();
  }

  group(StrategySettingsPage, () {
    testWidgets('shows the check-in day, Monday by default', (tester) async {
      await pump(tester);
      expect(find.text('Monday'), findsOneWidget);
      expect(
        find.text(
          'Individually configure which modules can appear during your '
          'check in.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the check-in day is chosen from the week, Sunday first', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Check-in Day'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Sunday')).dy,
        lessThan(tester.getTopLeft(find.text('Saturday')).dy),
      );
      await tester.tap(find.text('Saturday'));
      await tester.pumpAndSettle();

      expect(repository.saved.single.checkInWeekday, 7);
      expect(find.text('Saturday'), findsOneWidget);
    });

    testWidgets('a module switch saves', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Fasting'));
      await tester.pumpAndSettle();
      expect(repository.saved.single.fastingEnabled, isFalse);
    });

    testWidgets('shows nothing when no one is signed in', (tester) async {
      final appBloc = signedInAppBloc();
      when(() => appBloc.state).thenReturn(const AppUnauthenticated());
      await tester.pumpApp(const StrategySettingsPage(), appBloc: appBloc);
      expect(find.text('Strategy'), findsNothing);
    });
  });
}
