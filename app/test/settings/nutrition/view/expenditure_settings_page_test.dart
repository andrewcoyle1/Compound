import 'package:body_repository/body_repository.dart';
import 'package:compound/settings/nutrition/view/expenditure_settings_page.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

import '../../../helpers/helpers.dart';
import '../helpers.dart';

void main() {
  late SpyCheckInRepository repository;

  setUp(() => repository = SpyCheckInRepository());

  Future<void> pump(WidgetTester tester) async {
    useTallView(tester);
    await tester.pumpApp(
      ExpenditureSettingsPage(now: () => DateTime(2026, 10, 15, 12)),
      appBloc: signedInAppBloc(),
      checkInRepository: repository,
      nutritionRepository: SpyNutritionRepository(),
      bodyRepository: InMemoryBodyRepository(),
      userRepository: InMemoryUserRepository(
        users: {uid: const UserModel(userId: uid)},
      ),
    );
    await tester.pumpAndSettle();
  }

  group(ExpenditureSettingsPage, () {
    testWidgets("shows today's figure and where it came from", (tester) async {
      await pump(tester);
      expect(find.textContaining(' KCAL', findRichText: true), findsOneWidget);
      expect(
        find.textContaining(
          'Calibrating: estimated from your profile until 21 days and 14 '
          'weigh-ins are logged',
        ),
        findsOneWidget,
      );
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Use Default'), findsNothing);
    });

    testWidgets('a picked equation is saved, and fixed says so', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('BMR Equation'));
      await tester.pumpAndSettle();
      expect(
        find.text('Older, and tends to read slightly high.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cunningham'));
      await tester.pumpAndSettle();
      expect(repository.saved.single.bmrEquation, BmrEquation.cunningham);

      await tester.tap(find.text('Calculation Mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fixed').last);
      await tester.pumpAndSettle();
      expect(
        repository.saved.last.calculationMode,
        ExpenditureCalculationMode.fixed,
      );
      // The picker's value and the estimate's source.
      expect(find.text('Fixed'), findsNWidgets(2));
    });

    testWidgets('a start date is picked, shown, and cleared', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Calculation Start Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(repository.saved.single.calculationStartDate, DateTime(2026, 10));
      expect(find.text('Use Default'), findsOneWidget);

      await tester.tap(find.text('Use Default'));
      await tester.pumpAndSettle();
      expect(repository.saved.last.calculationStartDate, isNull);
      expect(find.text('Default'), findsOneWidget);
    });

    testWidgets('dismissing the date picker saves nothing', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Calculation Start Date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.saved, isEmpty);
    });

    testWidgets('the step switch saves', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Step-Informed Updates'));
      await tester.pumpAndSettle();
      expect(repository.saved.single.stepInformedUpdates, isTrue);
    });
  });
}
