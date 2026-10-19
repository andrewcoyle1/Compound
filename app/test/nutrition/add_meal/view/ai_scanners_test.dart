import 'package:ai_repository/ai_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/nutrition/add_meal/view/add_meal_page.dart';
import 'package:compound/nutrition/add_meal/view/amount_sheets.dart';
import 'package:compound/nutrition/cubit/meal_draft_cubit.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:image_repository/image_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

import '../../../helpers/helpers.dart';
import '../fake_ai.dart';
import '../recording_analytics.dart';

// The AI scanners in the meal logger, end to end on the staging flavor's
// canned AI answers and in-memory data: a meal photo, a description and a
// nutrition label, reviewed, put on the plate and logged.
void main() {
  const uid = 'uid';
  final now = DateTime.now();
  final mealDate = DateTime(now.year, now.month, now.day, 8);

  late AppBloc appBloc;
  late InMemoryNutritionRepository nutrition;
  late InMemoryFoodRepository foods;
  late MealDraftCubit drafts;
  late FakePhotoPicker picker;
  late FakeLiveCamera camera;
  late RecordingAnalytics analytics;

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: uid, isAnonymous: false)),
    );
    nutrition = InMemoryNutritionRepository();
    foods = InMemoryFoodRepository(
      foods: sampleFoods(uid: uid, now: now),
    );
    drafts = MealDraftCubit();
    picker = FakePhotoPicker();
    camera = FakeLiveCamera();
    analytics = RecordingAnalytics();
  });

  Future<void> pumpLogger(
    WidgetTester tester, {
    AiRepository? aiRepository,
    LabelTextReader? labelTextReader,
    LiveCamera? liveCamera,
  }) async {
    final router = GoRouter(
      initialLocation: '/log',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Text('home'),
          routes: [
            GoRoute(
              path: 'log',
              builder: (_, _) => AddMealPage(
                meal: newMeal(uid: uid, date: mealDate, mealId: 'MEAL'),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpApp(
      const SizedBox.shrink(),
      router: router,
      appBloc: appBloc,
      nutritionRepository: nutrition,
      foodRepository: foods,
      mealDraftCubit: drafts,
      photoPicker: picker,
      aiRepository: aiRepository,
      labelTextReader: labelTextReader,
      liveCamera: liveCamera ?? camera,
      analyticsRepository: analytics,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String title) async {
    final chip = find.widgetWithText(AppChip, title);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  Future<MealLogModel> loggedMeal() async =>
      (await nutrition.watchMeals(uid).first).single;

  group('AI photo', () {
    testWidgets('a meal photo is estimated; Add All and a corrected row go '
        'on the plate, and Log saves them', (tester) async {
      await pumpLogger(tester);
      await openTab(tester, 'AI');
      expect(find.textContaining("isn't stored by Compound"), findsOneWidget);

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();
      expect(find.text('AI Estimate'), findsOneWidget);
      expect(find.text('Grilled Chicken Breast'), findsOneWidget);
      expect(find.text('Add All (3)'), findsOneWidget);

      await tester.tap(find.text('Add All (3)'));
      await tester.pumpAndSettle();
      expect(find.text('3 on plate'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);

      // A row opens its amount at the estimate, to correct it first.
      await tester.tap(find.text('Brown Rice'));
      await tester.pumpAndSettle();
      expect(find.byType(FoodAmountSheet), findsOneWidget);
      expect(find.widgetWithText(TextField, '100'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '50');
      await tester.tap(find.text('Add to Plate'));
      await tester.pumpAndSettle();
      expect(find.text('4 on plate'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppCtaButton, 'Log'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      final meal = await loggedMeal();
      expect(meal.items.map((item) => item.displayName), [
        'Grilled Chicken Breast',
        'Brown Rice',
        'Steamed Broccoli',
        'Brown Rice',
      ]);
      expect(meal.items.last.amount, 50);
      // 111 kcal at 100 g, so 55.5 at 50 g.
      expect(meal.items.last.nutrients.values[NutrientKey.calories], 55.5);
      // The estimates are not library foods.
      expect(
        (await foods.watchFoods(uid).first).map((food) => food.name),
        isNot(contains('Brown Rice')),
      );
      expect(
        analytics.names,
        containsAllInOrder(<String>[
          'NutritionLibraryPickerView_Tab_Selected',
          'FoodPhotoScanner_Capture',
          'FoodPhotoScannerView_Analyse_Success',
          'FoodPhotoScanner_AddAll',
          'FoodPhotoScanner_AddItem',
        ]),
      );
    });

    testWidgets('a failed estimate says so; Retake opens the camera again', (
      tester,
    ) async {
      final ai = FakeAi()..fails = true;
      await pumpLogger(tester, aiRepository: ai.repository);
      await openTab(tester, 'AI');
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining("Couldn't recognize the food"),
        findsOneWidget,
      );

      ai
        ..fails = false
        ..json = '{"items": []}';
      await tester.tap(find.text('Retake'));
      await tester.pumpAndSettle();
      expect(picker.picks, hasLength(2));
      expect(find.text('No Foods Recognized'), findsOneWidget);
    });

    testWidgets('a refused camera offers Settings', (tester) async {
      picker.error = const PhotoAccessDeniedException();
      await pumpLogger(tester);
      await openTab(tester, 'AI');
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();
      expect(find.text('Camera Access Is Off'), findsOneWidget);

      await tester.tap(find.text('Open Settings'));
      await tester.pump();
      expect(picker.settingsOpened, 1);
    });

    testWidgets('no camera says so', (tester) async {
      picker.error = Exception('no camera');
      await pumpLogger(tester);
      await openTab(tester, 'AI');
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();
      expect(find.text('Camera Unavailable'), findsOneWidget);
    });
  });

  group('Describe', () {
    testWidgets('a description is estimated, a row is added through its '
        'amount, and logged', (tester) async {
      await pumpLogger(tester);
      await openTab(tester, 'Describe');
      expect(find.text('0/500'), findsOneWidget);
      final analyze = find.widgetWithText(AppCtaButton, 'Analyze');
      expect(tester.widget<AppCtaButton>(analyze).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('FoodPicker.describeField')),
        'Chicken, rice and broccoli',
      );
      await tester.pump();
      expect(find.text('26/500'), findsOneWidget);
      await tester.tap(analyze);
      await tester.pumpAndSettle();
      expect(find.text('Steamed Broccoli'), findsOneWidget);

      await tester.tap(find.byTooltip('Add Grilled Chicken Breast'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '150'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppCtaButton, 'Log').last);
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      final item = (await loggedMeal()).items.single;
      expect(item.displayName, 'Grilled Chicken Breast');
      expect(item.amount, 150);
      expect(item.nutrients.values[NutrientKey.calories], closeTo(248, 1e-9));
      expect(analytics.names, contains('MealDescribe_Submit'));
    });

    testWidgets('a failed description says so', (tester) async {
      final ai = FakeAi()..fails = true;
      await pumpLogger(tester, aiRepository: ai.repository);
      await openTab(tester, 'Describe');
      await tester.enterText(
        find.byKey(const Key('FoodPicker.describeField')),
        'Toast',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(AppCtaButton, 'Analyze'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining("Couldn't work out the foods"),
        findsOneWidget,
      );
    });

    testWidgets('nothing recognized says how to describe', (tester) async {
      final ai = FakeAi();
      await pumpLogger(tester, aiRepository: ai.repository);
      await openTab(tester, 'Describe');
      await tester.enterText(
        find.byKey(const Key('FoodPicker.describeField')),
        'Something',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(AppCtaButton, 'Analyze'));
      await tester.pumpAndSettle();
      expect(find.text('No Foods Recognized'), findsOneWidget);
    });
  });

  group('Label', () {
    Future<void> openLabel(WidgetTester tester) async {
      // A phone, tall enough for the camera, the field and Parse Label.
      tester.useSize(const Size(402, 1400));
      await openTab(tester, 'Barcode');
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('FoodPicker.scanningMode')),
          matching: find.text('Label'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets("a label's food is saved to the library and goes on the "
        'plate through its amount', (tester) async {
      await pumpLogger(tester);
      await openLabel(tester);
      final parse = find.widgetWithText(AppCtaButton, 'Parse Label');
      expect(tester.widget<AppCtaButton>(parse).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('FoodPicker.labelField')),
        'Energy 380kcal Protein 30g',
      );
      await tester.pump();
      await tester.tap(parse);
      await tester.pumpAndSettle();
      expect(find.text('Protein Shake Mix'), findsOneWidget);
      expect(find.text('per 100g'), findsOneWidget);
      expect(find.textContaining('Sodium: 250 mg'), findsOneWidget);

      await tester.tap(find.text('Use This Food'));
      await tester.pumpAndSettle();
      expect(find.byType(FoodAmountSheet), findsOneWidget);
      await tester.tap(find.text('Add to Plate'));
      await tester.pumpAndSettle();
      expect(find.text('1 on plate'), findsOneWidget);

      final saved = (await foods.watchFoods(uid).first).singleWhere(
        (food) => food.name == 'Protein Shake Mix',
      );
      expect(saved.authorId, uid);
      expect(drafts.state?.items.single.sourceId, saved.ingredientId);
      expect(
        analytics.names,
        containsAllInOrder(<String>[
          'BarcodeScanner_ParseLabel',
          'BarcodeScannerView_ParseLabel_Success',
          'BarcodeScanner_SaveIngredient',
          'BarcodeScannerView_SaveIngredient_Success',
        ]),
      );
    });

    testWidgets('a label that cannot be read says so; Scan Again clears a '
        'result', (tester) async {
      final ai = FakeAi()..fails = true;
      await pumpLogger(tester, aiRepository: ai.repository);
      await openLabel(tester);
      await tester.enterText(
        find.byKey(const Key('FoodPicker.labelField')),
        'Energy',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(AppCtaButton, 'Parse Label'));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't read this label"), findsOneWidget);

      ai
        ..fails = false
        ..json =
            '{"name": "Oat Milk", "measurementMethod": "volume", '
            '"calories": 46}';
      await tester.tap(find.widgetWithText(AppCtaButton, 'Parse Label'));
      await tester.pumpAndSettle();
      expect(find.text('per 100ml'), findsOneWidget);
      expect(camera.isOpen, isFalse);
      await tester.tap(find.widgetWithText(AppCtaButton, 'Scan Again'));
      await tester.pumpAndSettle();
      expect(find.text('Oat Milk'), findsNothing);
      expect(find.widgetWithText(AppCtaButton, 'Parse Label'), findsOneWidget);
      expect(camera.isOpen, isTrue);
    });

    testWidgets('the live camera reads a label that holds still, and the '
        'AI reads it once', (tester) async {
      await pumpLogger(tester);
      await openLabel(tester);
      expect(find.text('Hold the label in the frame'), findsOneWidget);
      expect(find.byKey(const Key('FakeLiveCamera.preview')), findsOneWidget);
      expect(
        find.text('Scan a nutrition label, or type or paste its text.'),
        findsOneWidget,
      );

      // Two reads, half a second apart, that agree.
      camera.send();
      await tester.pump(const Duration(milliseconds: 500));
      camera.send();
      await tester.pumpAndSettle();

      expect(find.text('Protein Shake Mix'), findsOneWidget);
      expect(camera.isOpen, isFalse);
      expect(
        analytics.names,
        containsAllInOrder(<String>[
          'BarcodeScanner_LabelLocked',
          'BarcodeScanner_ParseLabel',
        ]),
      );
      expect(
        analytics.names.where((name) => name == 'BarcodeScanner_ParseLabel'),
        hasLength(1),
      );
    });

    testWidgets("in staging, the bundled label's frames are read live", (
      tester,
    ) async {
      await pumpLogger(tester, liveCamera: SampleLiveCamera());
      await openLabel(tester);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Protein Shake Mix'), findsOneWidget);
      expect(find.text('per 100g'), findsOneWidget);
    });

    testWidgets("a library photo's text fills the field, ready to parse", (
      tester,
    ) async {
      await pumpLogger(tester);
      await openLabel(tester);

      await tester.tap(find.byKey(const Key('FoodPicker.labelChoosePhoto')));
      await tester.pumpAndSettle();
      expect(picker.picks.single.$1, PhotoSource.library);
      expect(camera.isOpen, isFalse);
      expect(find.text(SampleLabelTextReader.sampleLabel), findsOneWidget);
      expect(find.text('Label text captured'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppCtaButton, 'Parse Label'));
      await tester.pumpAndSettle();
      expect(find.text('Protein Shake Mix'), findsOneWidget);
    });

    testWidgets('Scan Again goes back to the live camera after a photo', (
      tester,
    ) async {
      await pumpLogger(tester);
      await openLabel(tester);
      await tester.tap(find.byKey(const Key('FoodPicker.labelChoosePhoto')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('FoodPicker.labelScanAgain')));
      await tester.pumpAndSettle();
      expect(camera.isOpen, isTrue);
      expect(find.text('Hold the label in the frame'), findsOneWidget);
    });

    testWidgets('the torch lights and says so', (tester) async {
      await pumpLogger(tester);
      await openLabel(tester);

      await tester.tap(find.byTooltip('Turn on flashlight'));
      await tester.pumpAndSettle();

      expect(camera.torch, isTrue);
      expect(find.byTooltip('Turn off flashlight'), findsOneWidget);
    });

    testWidgets('the camera is let go in the background', (tester) async {
      await pumpLogger(tester);
      await openLabel(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(camera.isOpen, isFalse);
      expect(find.byKey(const Key('FakeLiveCamera.preview')), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(camera.isOpen, isTrue);
      expect(camera.opened, 2);
    });

    testWidgets('a photo with no text says so; the library is offered '
        'too', (tester) async {
      await pumpLogger(
        tester,
        labelTextReader: const SampleLabelTextReader(text: ''),
      );
      await openLabel(tester);

      await tester.tap(find.text('Choose from Library'));
      await tester.pumpAndSettle();
      expect(picker.picks.single.$1, PhotoSource.library);
      expect(find.textContaining('Hold the camera steady'), findsOneWidget);
      expect(
        tester
            .widget<AppCtaButton>(
              find.widgetWithText(AppCtaButton, 'Parse Label'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('a refused camera offers Settings; a missing one says '
        'so', (tester) async {
      camera.error = const PhotoAccessDeniedException();
      await pumpLogger(tester);
      await openLabel(tester);

      expect(
        find.text(
          'Allow camera access in Settings to scan a label, or type its '
          'text.',
        ),
        findsOneWidget,
      );
      expect(find.text('Hold the label in the frame'), findsNothing);
      expect(find.byKey(const Key('FoodPicker.labelScanAgain')), findsNothing);
      await tester.tap(find.text('Open Settings'));
      expect(picker.settingsOpened, 1);

      camera.error = Exception('no camera');
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('FoodPicker.scanningMode')),
          matching: find.text('Barcode'),
        ),
      );
      await tester.pumpAndSettle();
      await openLabel(tester);
      expect(find.textContaining("The camera isn't available"), findsOneWidget);
      expect(find.text('Open Settings'), findsNothing);
    });

    testWidgets('changing mode starts over', (tester) async {
      await pumpLogger(tester);
      await openLabel(tester);
      await tester.enterText(
        find.byKey(const Key('FoodPicker.labelField')),
        'Energy',
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('FoodPicker.scanningMode')),
          matching: find.text('Barcode'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('FoodPicker.labelField')), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('FoodPicker.scanningMode')),
          matching: find.text('Label'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Energy'), findsNothing);
    });
  });
}
