import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/gym_profiles/view/gym_profile_page.dart';
import 'package:compound/gym_profiles/view/gym_profiles_page.dart';
import 'package:compound/gym_profiles/view/stack_machine_editor.dart';
import 'package:compound/gym_profiles/view/weight_list_editor.dart';
import 'package:compound/shell/shell.dart';
import 'package:compound/workout_editor/view/workout_wizard_pages.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/app_repositories.dart';

/// The gym editor in the app as the staging flavor runs it: the sample user
/// and their sample gym, in memory.
void main() {
  const uid = sampleUserId;
  final now = DateTime.now();
  late InMemoryTrainingLibraryRepository library;
  late InMemoryUserRepository users;

  Future<void> pumpGymApp(
    WidgetTester tester, {
    List<GymProfileModel>? gyms,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    library = InMemoryTrainingLibraryRepository(
      workoutTemplates: sampleUserWorkoutTemplates,
      gymProfiles: gyms ?? sampleGymProfiles,
    );
    users = InMemoryUserRepository(
      users: {uid: sampleUser(now: now)},
      settings: {uid: sampleUserSettings(now: now)},
    );
    await tester.pumpWidget(
      App(
        socialRepository: emptySocialRepository(),
        coachRepository: silentCoachRepository(),
        purchasesRepository: FakePurchasesRepository(),
        authRepository: InMemoryAuthRepository(
          user: InMemoryAuthRepository.sampleUser,
        ),
        userRepository: users,
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: library,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String routeName) async {
    final router = GoRouter.of(tester.element(find.byType(AppShell)));
    unawaited(router.pushNamed(routeName));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  Future<GymProfileModel> stored(WidgetTester tester, String id) async {
    final gyms = await tester.runAsync(
      () => library.watchGymProfiles(uid).first,
    );
    return gyms!.firstWhere((gym) => gym.id == id);
  }

  testWidgets('Settings › Gym Profiles: switching equipment and adding a '
      'weight is saved on leaving', (tester) async {
    await pumpGymApp(tester);
    await open(tester, GymProfilesPage.name);
    expect(find.text('Favorite Gym Profile'), findsOneWidget);
    expect(find.text('Platinum Gym Malahide'), findsOneWidget);

    await tap(tester, find.text('Platinum Gym Malahide'));
    expect(find.byType(GymProfileView), findsOneWidget);
    final dumbbells = GymEditorRules.item(
      sampleGymProfiles.single,
      GymEquipmentList.freeWeights,
      'dumbbells',
    )!;
    await tap(tester, find.byKey(const Key('GymProfile.active.dumbbells')));

    // Edit Weights › + › 31 kg.
    await tap(tester, find.byKey(const Key('GymProfile.edit.dumbbells')));
    expect(find.byType(WeightListEditorPage), findsOneWidget);
    await tap(tester, find.byTooltip('Add free weight'));
    expect(find.text('Enter a weight above zero.'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      '31',
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('Confirm'));
    expect(find.text('31 kg'), findsOneWidget);
    await back(tester);
    await back(tester);

    final saved = await stored(tester, 'sample-gym');
    final edited =
        GymEditorRules.item(saved, GymEquipmentList.freeWeights, 'dumbbells')!
            as FreeWeights;
    expect(edited.isActive, !dumbbells.isActive);
    expect(
      edited.range.where((w) => w.availableWeights == 31 && w.isActive),
      hasLength(1),
    );
  });

  testWidgets('machines: added, stacked, ranged, duplicated, deleted, and a '
      'plate-loaded machine set to one side', (tester) async {
    await pumpGymApp(tester);
    await open(tester, GymProfilesPage.name);
    await tap(tester, find.text('Platinum Gym Malahide'));

    // Add Machine… opens the new machine's stacks.
    await tap(tester, find.byTooltip('Add Machine…'));
    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      'Hammer Pulldown',
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('Confirm'));
    expect(find.byType(StackMachineEditorPage), findsOneWidget);
    expect(find.text('Hammer Pulldown'), findsWidgets);

    // + › a second stack.
    await tap(tester, find.byTooltip('Add Range'));
    await tester.enterText(
      find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(TextField),
          )
          .first,
      'Stack B',
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('Confirm'));
    expect(find.text('Stack B'), findsOneWidget);

    // Edit Range › Uneven stack, then closed: with no pins it goes back.
    await tap(tester, find.text('Edit Range').last);
    await tap(tester, find.text('Uneven stack'));
    expect(find.text('Pin weight'), findsOneWidget);
    await tap(tester, find.byTooltip('Close'));
    await back(tester);

    // Duplicate by swipe, then delete the copy from the long press, found
    // by searching.
    await tester.enterText(
      find.byKey(const Key('GymProfile.search')),
      'hammer',
    );
    await tester.pumpAndSettle();
    await tester.drag(find.text('Hammer Pulldown'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tap(tester, find.byIcon(AppSymbols.duplicate));
    expect(find.text('Hammer Pulldown 2'), findsOneWidget);
    await tester.ensureVisible(find.text('Hammer Pulldown 2'));
    await tester.longPress(find.text('Hammer Pulldown 2'));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Delete'));
    expect(find.text('Delete Machine?'), findsOneWidget);
    await tap(tester, find.text('Delete').last);
    expect(find.text('Hammer Pulldown 2'), findsNothing);

    // A plate-loaded machine's base weight, on one side.
    final plateMachine = sampleGymProfiles.single.plateLoadedMachines.first;
    await tester.enterText(
      find.byKey(const Key('GymProfile.search')),
      plateMachine.name,
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(Key('GymProfile.edit.${plateMachine.id}')));
    await tap(tester, find.text('One side'));
    await tap(tester, find.byTooltip('Close'));
    expect(find.textContaining('one side'), findsWidgets);

    await back(tester);
    final gym = await stored(tester, 'sample-gym');
    final machine = gym.cableMachines.firstWhere(
      (m) => m.name == 'Hammer Pulldown',
    );
    expect(machine.ranges.map((r) => r.name), contains('Stack B'));
    expect(machine.ranges.every((r) => r.weights == null), isTrue);
    expect(
      gym.cableMachines.where((m) => m.name == 'Hammer Pulldown 2'),
      isEmpty,
    );
    expect(
      gym.plateLoadedMachines
          .firstWhere((m) => m.id == plateMachine.id)
          .sleeves,
      1,
    );
  });

  testWidgets('a gym is deleted after asking, and a new one added', (
    tester,
  ) async {
    await pumpGymApp(tester);
    await open(tester, GymProfilesPage.name);

    await tester.drag(
      find.text('Platinum Gym Malahide'),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byIcon(AppSymbols.delete));
    expect(find.text('Delete Gym Profile?'), findsOneWidget);
    await tap(tester, find.text('Delete').last);
    expect(find.text('No Gym Profiles'), findsOneWidget);
    expect(
      await tester.runAsync(() => library.watchGymProfiles(uid).first),
      isEmpty,
    );

    await tap(tester, find.text('Add a Gym Profile'));
    await tester.enterText(find.byKey(const Key('GymProfile.name')), 'Garage');
    await tester.pumpAndSettle();
    await back(tester);
    expect(find.text('Garage'), findsOneWidget);
  });

  testWidgets("Choose Gym Profile's Create Gym Profile names a gym, sets it "
      'up and comes back to the list', (tester) async {
    await pumpGymApp(tester, gyms: const []);
    await tap(tester, find.text('Training').last);
    await tap(tester, find.byTooltip('Add training'));
    await tap(tester, find.text('New Workout'));
    await tester.enterText(find.byKey(const Key('NameWorkout.name')), 'Legs');
    await tester.pump();
    await tap(tester, find.byKey(const Key('NameWorkout.continue')));
    expect(find.byType(ChooseGymProfileView), findsOneWidget);

    await tap(tester, find.text('Create Gym Profile'));
    expect(find.byType(CreateGymProfileView), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('CreateGymProfile.name')),
      'Home Gym',
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Continue'));
    expect(find.byType(GymProfileView), findsOneWidget);
    await tap(tester, find.text('Continue'));

    expect(find.byType(ChooseGymProfileView), findsOneWidget);
    expect(find.text('Home Gym'), findsOneWidget);
    final user = await tester.runAsync(() => users.watchUser(uid).first);
    final gyms = await tester.runAsync(
      () => library.watchGymProfiles(uid).first,
    );
    expect(user!.submittedFavouriteGymProfileId, gyms!.single.id);
  });

  testWidgets('bands, collars, an accessory and add-ons are edited in '
      'place', (tester) async {
    await pumpGymApp(tester);
    await open(tester, GymProfilesPage.name);
    await tap(tester, find.text('Platinum Gym Malahide'));
    Future<void> search(String query) async {
      await tester.enterText(find.byKey(const Key('GymProfile.search')), query);
      await tester.pumpAndSettle();
    }

    final sample = sampleGymProfiles.single;
    Future<void> type(int index, String text) async {
      await tester.enterText(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(TextField),
            )
            .at(index),
        text,
      );
      await tester.pumpAndSettle();
    }

    // A band: colour, label and resistance; the label is needed.
    final bands = sample.bands.first;
    await search(bands.name);
    await tap(tester, find.byKey(Key('GymProfile.edit.${bands.id}')));
    await tap(tester, find.byTooltip('Add band'));
    await tap(tester, find.bySemanticsLabel('Blue'));
    await type(1, '33');
    expect(find.text('Please enter a name for this weight.'), findsOneWidget);
    await type(0, 'Thick');
    await tap(tester, find.byTooltip('Confirm'));
    expect(find.text('Thick'), findsOneWidget);
    expect(find.text('Up to 33 kg'), findsOneWidget);
    // Swiped away again.
    await tester.drag(find.text('Thick'), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('Thick'), findsNothing);
    await back(tester);

    // The barbell's collars, typed in pounds.
    final barbell = sample.loadableBars.firstWhere((b) => b.id == 'barbell');
    await search(barbell.name);
    await tap(tester, find.byKey(const Key('GymProfile.edit.barbell')));
    await tap(tester, find.text('lb').first);
    await tester.enterText(
      find.descendant(
        of: find.ancestor(
          of: find.text('Each collar'),
          matching: find.byType(AppNumberField),
        ),
        matching: find.byType(TextField),
      ),
      '5.512',
    );
    await tester.pumpAndSettle();
    await back(tester);

    // An accessory's weight.
    final accessory = sample.loadableAccessoryEquipment.first;
    await search(accessory.name);
    await tap(tester, find.byKey(Key('GymProfile.edit.${accessory.id}')));
    await type(0, '4');
    await tap(tester, find.byTooltip('Close'));

    // A stack's add-on.
    final cable = sample.cableMachines.first;
    await search(cable.name);
    await tap(tester, find.byKey(Key('GymProfile.edit.${cable.id}')));
    await tap(tester, find.text('Edit Range').first);
    await type(3, '2');
    await tap(tester, find.text('Add').last);
    expect(find.text('+2 kg'), findsOneWidget);
    await tap(tester, find.byTooltip('Close'));
    await back(tester);
    await back(tester);

    final gym = await stored(tester, 'sample-gym');
    final bar =
        GymEditorRules.item(gym, GymEquipmentList.loadableBars, 'barbell')!
            as LoadableBars;
    expect(bar.collarWeight, closeTo(2.5, 0.001));
    expect(
      (GymEditorRules.item(
                gym,
                GymEquipmentList.loadableAccessoryEquipment,
                accessory.id,
              )!
              as LoadableAccessoryEquipment)
          .baseWeight,
      4,
    );
    final stacks =
        (GymEditorRules.item(gym, GymEquipmentList.cableMachines, cable.id)!
                as StackMachine)
            .ranges;
    expect(stacks.expand((s) => s.addOns), [2]);
  });

  testWidgets("the tracker's Gym Settings opens the workout's gym", (
    tester,
  ) async {
    await pumpGymApp(tester);
    await tap(tester, find.text('Training').last);
    await tap(tester, find.text('Workouts'));
    await tap(tester, find.text('My Upper Body'));
    await tap(tester, find.text('Start Workout'));
    expect(find.byType(WorkoutTrackerView), findsOneWidget);

    await tap(tester, find.byTooltip('Workout options'));
    await tap(tester, find.text('Gym Settings'));
    expect(find.byType(GymProfileView), findsOneWidget);
    expect(find.text('Platinum Gym Malahide'), findsOneWidget);
  });
}
