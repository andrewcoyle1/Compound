import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart';
import 'package:compound/nutrition/cubit/meal_draft_cubit.dart';
import 'package:compound/nutrition/view/widgets/meal_draft_bar.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../../helpers/helpers.dart';

class _MockActiveWorkoutCubit extends MockCubit<ActiveWorkoutState>
    implements ActiveWorkoutCubit;

/// Swift `MealAccessoryPresenterTests` and the tab accessory cases of
/// `AppShellPresenterTests`.
void main() {
  final now = DateTime.now();
  final meals = sampleMealLogs(uid: 'me', now: now);
  late ActiveWorkoutCubit workout;

  setUp(() {
    workout = _MockActiveWorkoutCubit();
    when(() => workout.state).thenReturn(const ActiveWorkoutState());
  });

  Future<List<MealLogModel>> pump(
    WidgetTester tester,
    MealDraftCubit drafts,
  ) async {
    final opened = <MealLogModel>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(bottomNavigationBar: MealDraftBar()),
        ),
        GoRoute(
          path: AddMealPage.path,
          name: AddMealPage.name,
          builder: (_, state) {
            opened.add(state.extra! as MealLogModel);
            return const Text('logger');
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpApp(
      const SizedBox.shrink(),
      router: router,
      mealDraftCubit: drafts,
      activeWorkoutCubit: workout,
    );
    await tester.pump();
    return opened;
  }

  group(MealDraftBar, () {
    testWidgets('a draft meal shows the bar, which reopens it', (tester) async {
      final drafts = MealDraftCubit()..keep(meals.first);
      final opened = await pump(tester, drafts);
      expect(find.text('Unlogged meal'), findsOneWidget);
      final count = meals.first.items.length;
      expect(
        find.bySemanticsLabel(
          count == 1
              ? 'Continue draft meal, 1 item'
              : 'Continue draft meal, $count items',
        ),
        findsOneWidget,
      );
      expect(find.textContaining(' kcal'), findsOneWidget);
      await tester.tap(find.text('Unlogged meal'));
      await tester.pumpAndSettle();
      expect(opened.single.mealId, meals.first.mealId);
    });

    testWidgets('follows the draft after it changes', (tester) async {
      final drafts = MealDraftCubit()..keep(meals.first);
      final opened = await pump(tester, drafts);
      final bigger = MealLogModel(
        mealId: meals.first.mealId,
        authorId: 'me',
        dayKey: meals.first.dayKey,
        date: meals.first.date,
        items: [
          for (var i = 0; i < 3; i++)
            MealItemModel(
              itemId: 'i$i',
              sourceType: MealItemSourceType.quickAdd,
              sourceId: 'quick_add',
              displayName: 'Food $i',
              amount: 1,
              unit: 'serving',
              nutrients: const NutrientMap({NutrientKey.calories: 100}),
            ),
        ],
      );
      drafts.keep(bigger);
      await tester.pump();
      expect(find.textContaining('3 items · '), findsOneWidget);
      await tester.tap(find.text('Unlogged meal'));
      await tester.pumpAndSettle();
      expect(opened.single.items, hasLength(3));
    });

    testWidgets('nothing without a draft', (tester) async {
      await pump(tester, MealDraftCubit());
      expect(find.text('Unlogged meal'), findsNothing);
    });

    testWidgets('a running workout has the place instead', (tester) async {
      when(() => workout.state).thenReturn(
        ActiveWorkoutState(
          status: ActiveWorkoutStatus.active,
          session: fixtureSession('w', author: 'me', finished: false),
        ),
      );
      await pump(tester, MealDraftCubit()..keep(meals.first));
      expect(find.text('Unlogged meal'), findsNothing);
    });
  });
}
