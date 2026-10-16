import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/gym_profiles/view/gym_profile_page.dart';
import 'package:compound/gym_profiles/view/gym_profiles_page.dart';
import 'package:compound/nutrition/foods/view/food_detail_page.dart';
import 'package:compound/nutrition/foods/view/foods_page.dart';
import 'package:compound/nutrition/nutrition.dart';
import 'package:compound/nutrition/recipes/view/create_recipe_pages.dart';
import 'package:compound/nutrition/recipes/view/recipe_detail_page.dart';
import 'package:compound/nutrition/recipes/view/recipes_page.dart';
import 'package:compound/shell/shell.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:image_repository/image_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/photos.dart';

// The whole app on the staging flavor's in-memory data: a photo on a new
// food, on a new recipe, on a gym, and on the onboarding name question, each
// uploaded to Swift's path and shown where Swift shows it.
void main() {
  const uid = sampleUserId;
  final now = DateTime.now();
  late InMemoryImageRepository images;
  late InMemoryFoodRepository foods;
  late InMemoryTrainingLibraryRepository library;
  late InMemoryUserRepository users;

  Future<void> pumpApp(
    WidgetTester tester, {
    String userId = uid,
    UserModel? profile,
    AuthUser user = InMemoryAuthRepository.sampleUser,
  }) async {
    tester.view
      ..physicalSize = const Size(1290, 2796)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    images = InMemoryImageRepository();
    final food = sampleFoods(uid: uid, now: now);
    foods = InMemoryFoodRepository(
      foods: food,
      recipes: sampleRecipes(uid: uid, now: now, foods: food),
    );
    library = InMemoryTrainingLibraryRepository(
      workoutTemplates: sampleUserWorkoutTemplates,
      gymProfiles: sampleGymProfiles,
    );
    users = InMemoryUserRepository(
      users: {userId: profile ?? sampleUser(now: now)},
      settings: {uid: sampleUserSettings(now: now)},
    );
    await tester.pumpWidget(
      App(
        purchasesRepository: FakePurchasesRepository(),
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: library,
        authRepository: InMemoryAuthRepository(user: user),
        userRepository: users,
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
        foodRepository: foods,
        imageRepository: images,
        photoPicker: FakePhotoPicker(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openNutritionRow(WidgetTester tester, String key) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/nutrition');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(Key(key)),
      200,
      scrollable: find
          .descendant(
            of: find.byType(NutritionView),
            matching: find.byType(Scrollable),
          )
          .last,
    );
    await tap(tester, find.byKey(Key(key)));
  }

  /// The [StoredImage]s showing what was uploaded.
  Finder uploaded() => find.byWidgetPredicate(
    (widget) => widget is StoredImage && widget.url.startsWith('data:'),
  );

  testWidgets('a food photo is uploaded on Create and shown in its row and '
      'detail', (tester) async {
    await pumpApp(tester);
    await openNutritionRow(tester, 'Nutrition.foods');
    await tap(tester, find.byTooltip('Add ingredient'));

    await tap(tester, find.bySemanticsLabel('Choose food image'));
    expect(find.byKey(const Key('CreateFood.image')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('CreateFood.name')), 'Kefir');
    await tester.pump();
    await tap(tester, find.byKey(const Key('CreateFood.next')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('PortionDefinition.weight')),
        matching: find.byType(TextField),
      ),
      '250',
    );
    await tester.pump();
    await tap(tester, find.byKey(const Key('PortionDefinition.next')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('FoodDefinition.energy')),
        matching: find.byType(TextField),
      ),
      '150',
    );
    await tester.pump();
    await tap(tester, find.byKey(const Key('FoodDefinition.create')));

    expect(find.byType(FoodsView), findsOneWidget);
    final kefir = (await foods.watchFoods(uid).first).singleWhere(
      (food) => food.name == 'Kefir',
    );
    expect(images.images.keys, ['ingredient_templates/${kefir.ingredientId}']);
    expect(kefir.imageUrl, startsWith('data:image/jpeg'));
    // The library rows show pictures, a plain square for the rest.
    expect(uploaded(), findsOneWidget);
    expect(find.byType(StoredThumbnail), findsWidgets);

    await tap(tester, find.text('Kefir'));
    expect(find.byType(FoodDetailView), findsOneWidget);
    expect(find.byType(StoredHeroImage), findsOneWidget);
  });

  testWidgets('a recipe photo is uploaded on Create and shown on its detail', (
    tester,
  ) async {
    await pumpApp(tester);
    await openNutritionRow(tester, 'Nutrition.recipes');
    await tap(tester, find.byTooltip('Add recipe'));
    await tester.enterText(find.byKey(const Key('CreateRecipe.name')), 'stew');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('CreateRecipe.servings')),
        matching: find.byType(TextField),
      ),
      '2',
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Next'));
    expect(find.byType(RecipePreparationView), findsOneWidget);
    expect(find.text('Select Photo'), findsOneWidget);

    await tap(tester, find.byKey(const Key('RecipePreparation.photo')));
    expect(find.text('Select Photo'), findsNothing);
    await tap(tester, find.text('Create'));

    expect(find.byType(RecipesView), findsOneWidget);
    final stew = (await foods.watchRecipes(uid).first).singleWhere(
      (recipe) => recipe.name == 'Stew',
    );
    expect(images.images.keys, ['recipe_templates/${stew.recipeId}']);
    expect(stew.imageUrl, startsWith('data:image/jpeg'));
    expect(uploaded(), findsOneWidget);

    await tap(tester, find.text('Stew'));
    expect(find.byType(RecipeDetailView), findsOneWidget);
    expect(find.byType(StoredHeroImage), findsOneWidget);
  });

  testWidgets('a gym photo is saved at once, shown as its header and in the '
      'list, and kept by the save on leaving', (tester) async {
    await pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(AppShell)));
    unawaited(router.pushNamed(GymProfilesPage.name));
    await tester.pumpAndSettle();
    final gym = sampleGymProfiles.single;
    await tap(tester, find.text(gym.name));
    expect(find.byType(GymProfileView), findsOneWidget);
    expect(find.byType(StoredHeroImage), findsNothing);
    // The bundled equipment pictures lead their rows.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is StoredImage &&
            widget.url == 'assets/equipment/dumbbells_icon.webp',
      ),
      findsOneWidget,
    );

    await tap(tester, find.byTooltip('Add gym photo'));
    expect(find.byTooltip('Change gym photo'), findsOneWidget);
    expect(find.bySemanticsLabel('Gym photo'), findsOneWidget);
    expect(images.images.keys, ['users/$uid/gymProfiles/${gym.id}']);

    await tap(tester, find.byKey(const Key('GymProfile.active.dumbbells')));
    await tester.pageBack();
    await tester.pumpAndSettle();
    final stored = (await tester.runAsync(
      () => library.watchGymProfiles(uid).first,
    ))!.single;
    expect(stored.imageUrl, startsWith('data:image/jpeg'));
    expect(uploaded(), findsOneWidget);
  });

  testWidgets('the name question uploads a photo with the name, and can '
      'remove one', (tester) async {
    const anonymous = 'in-memory-anonymous';
    await pumpApp(
      tester,
      userId: anonymous,
      user: InMemoryAuthRepository.anonymousUser,
      // A new account, which onboarding opens on the name question.
      profile: UserModel(
        userId: anonymous,
        isAnonymous: true,
        creationDate: now,
      ),
    );
    expect(find.text('Add Photo (Optional)'), findsOneWidget);
    expect(find.byKey(const Key('NamePhoto.remove')), findsNothing);

    await tap(tester, find.byKey(const Key('NamePhoto.photo')));
    expect(find.bySemanticsLabel('Change Photo'), findsOneWidget);
    await tap(tester, find.byKey(const Key('NamePhoto.remove')));
    expect(find.bySemanticsLabel('Add Photo (Optional)'), findsOneWidget);
    await tap(tester, find.byKey(const Key('NamePhoto.photo')));

    await tester.enterText(find.byType(TextField).first, 'Sam');
    await tap(tester, find.text('Continue').last);

    expect(find.text('Continue'), findsWidgets);
    expect(images.images.keys, ['users/$anonymous/profile']);
    final profile = await users.watchUser(anonymous).first;
    expect(profile?.submittedProfileImage, startsWith('data:image/jpeg'));
    expect(profile?.submittedFirstName, 'Sam');
  });
}
