@Timeout(Duration(seconds: 30))
library;

import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/gym_profiles/view/gym_profile_page.dart';
import 'package:compound/workout_tracker/view/equipment_sheet.dart';
import 'package:compound/workout_tracker/view/plate_calculator_sheet.dart';
import 'package:compound/workout_tracker/workout_tracker.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/library_fixtures.dart';

/// The tracker's loading and equipment, through the whole app on the
/// staging data: the loading bar and plate calculator over the weight
/// keypad, bands and ±, and the equipment sheet with its scoped gym editor.
void main() {
  const uid = sampleUserId;
  final now = DateTime.now();

  ExerciseModel own(
    String id, {
    List<EquipmentRef> resistance = const [],
    bool assisted = false,
  }) => ExerciseModel.fromFirestore({
    ...fixtureLibraryExercise(
      id,
      variations: [
        EquipmentVariation(id: '$id-v', resistanceEquipment: resistance),
      ],
    ).toFirestore(),
    'author_id': uid,
    if (assisted) 'trackable_metrics': ['weightPerSideAssistance', 'reps'],
  });

  final bandedBench = own(
    'Banded Bench',
    resistance: const [
      EquipmentRef(kind: EquipmentKind.loadableBar, equipmentId: 'barbell'),
      EquipmentRef(
        kind: EquipmentKind.bands,
        equipmentId: 'long_elastic_bands',
      ),
    ],
  );
  final assistedDip = own('Assisted Dip', assisted: true);

  late InMemoryTrainingLibraryRepository library;

  /// The app on the staging data, with My Upper Body started.
  Future<ActiveWorkoutCubit> start(WidgetTester tester) async {
    library = InMemoryTrainingLibraryRepository(
      exercises: [bandedBench, assistedDip],
      workoutTemplates: sampleUserWorkoutTemplates,
      gymProfiles: sampleGymProfiles,
      workoutSettings: const [
        WorkoutSettings(authorId: uid, addSmartWarmUps: false),
      ],
    );
    await tester.pumpWidget(
      App(
        purchasesRepository: FakePurchasesRepository(),
        authRepository: InMemoryAuthRepository(
          user: InMemoryAuthRepository.sampleUser,
        ),
        userRepository: InMemoryUserRepository(
          users: {uid: sampleUser(now: now)},
          settings: {uid: sampleUserSettings(now: now)},
        ),
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        bodyRepository: InMemoryBodyRepository(),
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: library,
        activeSessionStore: InMemoryActiveSessionStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Training').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Workouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Upper Body'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Workout'));
    await tester.pumpAndSettle();
    return BlocProvider.of<ActiveWorkoutCubit>(
      tester.element(find.byType(WorkoutTrackerView)),
    );
  }

  Future<void> keys(WidgetTester tester, String keys) async {
    for (final key in keys.split(' ')) {
      await tester.tap(find.byKey(ValueKey('keypad-$key')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<GymProfileModel> savedGym() async =>
      (await library.watchGymProfiles(uid).first).single;

  testWidgets('the loading bar follows the weight, and the plate calculator '
      'saves the bar and plates to the gym', (tester) async {
    final cubit = await start(tester);
    final setId = (cubit.state.primaryAction! as r.LogSetAction).setId;
    await tester.tap(find.byKey(ValueKey('cell-$setId-weight')));
    await tester.pumpAndSettle();

    // The bare bar until a weight is typed, then its plates.
    expect(find.text('Empty bar = 20 kg'), findsOneWidget);
    await keys(tester, '7 0');
    expect(find.text('1 × 25'), findsOneWidget);
    expect(find.text('25 kg on each side + 20 kg bar = 70 kg'), findsOneWidget);

    // The plates key puts the bar away, and brings it back.
    await keys(tester, 'plates');
    expect(find.text('1 × 25'), findsNothing);
    await keys(tester, 'plates');
    expect(find.text('1 × 25'), findsOneWidget);

    // A weight the plates cannot make offers the nearest that they can.
    await keys(tester, 'delete 1');
    expect(find.text('Not loadable'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('keypad-use-72.5')));
    await tester.pumpAndSettle();
    expect(cubit.state.set(setId)!.weightKg, 72.5);
    await keys(tester, '7 0');

    // The calculator: the 15 kg bar, and the 2.5 kg plates off.
    await tester.tap(find.byKey(const ValueKey('keypad-loading')));
    await tester.pumpAndSettle();
    expect(find.byType(PlateCalculatorView), findsOneWidget);
    expect(find.text('Plate Calculator'), findsOneWidget);
    expect(
      find.text('Used for every exercise on this bar at this gym.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('plate-bar-barbell_2')));
    await tester.pumpAndSettle();
    expect(
      find.text('27.5 kg on each side + 15 kg bar = 70 kg'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('plate-2.5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plate-1.25')));
    await tester.pumpAndSettle();
    expect(find.text('Not loadable: 65 or 75 kg'), findsOneWidget);

    // Close changes nothing.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(
      GymEditorRules.loadedBar(await savedGym(), 'barbell')!.chosenBaseWeightId,
      isNull,
    );

    // Done saves both, and the keypad loads on them at once.
    await tester.tap(find.byKey(const ValueKey('keypad-loading')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plate-bar-barbell_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plate-1.25')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();
    expect(find.byType(PlateCalculatorView), findsNothing);
    expect(
      find.text('27.5 kg on each side + 15 kg bar = 70 kg'),
      findsOneWidget,
    );
    final gym = await savedGym();
    expect(
      GymEditorRules.loadedBar(gym, 'barbell')!.chosenBaseWeightId,
      'barbell_2',
    );
    expect(
      GymEditorRules.plateChoices(gym, ExerciseWeightUnit.kilograms).last,
      (weight: 1.25, isOn: false),
    );
  });

  testWidgets('bands sit beside the bar, and ± types assistance', (
    tester,
  ) async {
    final cubit = await start(tester);
    cubit.addExercises([bandedBench, assistedDip]);
    await tester.pumpAndSettle();

    final bench = cubit.state.session!.exercises.firstWhere(
      (e) => e.name == 'Banded Bench',
    );
    cubit.selectExercise(bench.id);
    await tester.pumpAndSettle();
    final benchSet = bench.sets.first.id;
    await tester.tap(find.byKey(ValueKey('cell-$benchSet-weight')));
    await tester.pumpAndSettle();
    await keys(tester, '6 0');
    expect(find.text('Bands'), findsOneWidget);
    final band = cubit.state.card.single.weightStep.bands.first;
    await tester.tap(find.byKey(ValueKey('keypad-band-$band')));
    await tester.pumpAndSettle();
    expect(cubit.state.set(benchSet)!.bands, [band]);
    expect(find.text('60 + $band'), findsOneWidget);
    await keys(tester, 'hide');

    final dip = cubit.state.session!.exercises.firstWhere(
      (e) => e.name == 'Assisted Dip',
    );
    cubit.selectExercise(dip.id);
    await tester.pumpAndSettle();
    final dipSet = dip.sets.first.id;
    await tester.tap(find.byKey(ValueKey('cell-$dipSet-weight')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('keypad-plates')), findsNothing);
    await keys(tester, 'sign 3 0');
    expect(cubit.state.set(dipSet)!.weightKg, -30);
    expect(find.text('-30'), findsOneWidget);
  });

  testWidgets('the equipment sheet chooses a variation, and edits its '
      "equipment in the workout's gym", (tester) async {
    final cubit = await start(tester);
    final bench = cubit.state.session!.exercises.first;
    expect(bench.name, 'Barbell Bench Press');

    Future<void> openSheet() async {
      await tester.tap(find.byTooltip('Exercise options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Equipment'));
      await tester.pumpAndSettle();
    }

    await openSheet();
    expect(find.text('Variation 1'), findsOneWidget);
    expect(
      find.text('Resistance: Barbell\nSupport: Flat Bench Press Station'),
      findsOneWidget,
    );
    await tester.tap(find.text('Variation 2'));
    await tester.pumpAndSettle();
    expect(find.text('Variation 2'), findsNothing);
    expect(
      cubit.state.exercise(bench.id)!.chosenVariationId,
      bench.equipmentVariations.last.id,
    );

    // Its equipment alone, under the variation's name; leaving saves, and
    // the sheet follows the gym.
    await openSheet();
    await tester.tap(find.byTooltip('Edit Variation 1 equipment'));
    await tester.pumpAndSettle();
    expect(find.byType(GymProfilePage), findsOneWidget);
    expect(find.text('Barbell'), findsOneWidget);
    expect(find.text('Dumbbells'), findsNothing);
    await tester.tap(find.byKey(const Key('GymProfile.active.barbell')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(GymProfilePage), findsNothing);
    expect(
      find.text(
        'Resistance: Barbell\nSupport: Flat Bench Press Station\n'
        'Not in this gym',
      ),
      findsOneWidget,
    );
    final gym = await savedGym();
    expect(GymEditorRules.loadedBar(gym, 'barbell'), isNull);
    expect(cubit.state.gym, gym);

    // Tapping the variation in use only closes.
    await tester.tap(find.text('Variation 2'));
    await tester.pumpAndSettle();
    expect(find.byType(EquipmentSheetView), findsNothing);
  });
}
