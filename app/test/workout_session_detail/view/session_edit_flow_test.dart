import 'package:app_ui/app_ui.dart' show AppToolbarButton;
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound_models/compound_models.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPicker;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show PopupMenuEntry;
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../../helpers/helpers.dart';

/// Editing a finished workout end to end on the staging flavor's in-memory
/// data: correct a set, add one and clear the notes, then save; throw an
/// edit away; change the duration; add an exercise; delete the workout;
/// and a workout already on Strava has its edit sent there.
void main() {
  const uid = sampleUserId;
  final now = DateTime.now();
  final yesterday = DateTime(now.year, now.month, now.day - 1, 7);

  WorkoutSetModel set(String id) => WorkoutSetModel(
    id: id,
    authorId: uid,
    index: 1,
    isWarmup: false,
    reps: 8,
    weightKg: 80,
    dateCreated: yesterday,
    completedAt: yesterday,
  );

  final workout = WorkoutSessionModel(
    id: 'edit-me',
    authorId: uid,
    name: 'Push Day',
    dateCreated: yesterday,
    dateModified: yesterday,
    endedAt: yesterday.add(const Duration(minutes: 64)),
    notes: 'Felt strong',
    likedByUserIds: const ['sample-friend-1'],
    exercises: [
      WorkoutExerciseModel(
        id: 'bench',
        authorId: uid,
        templateId: 'system-barbell-bench-press',
        name: 'Barbell Bench Press',
        trackingMode: TrackingMode.weightReps,
        index: 1,
        sets: [set('s1'), set('s2')],
      ),
    ],
  );
  final press = ExerciseModel.fromFirestore({
    ...fixtureLibraryExercise('aa-press', name: 'Aa Press').toFirestore(),
    'author_id': uid,
  });

  late InMemoryUserRepository users;
  late InMemoryWorkoutSessionRepository sessions;
  late AnalyticsRecorder analytics;
  late InMemoryTrainingLibraryRepository library;

  Widget app({StravaRepository? strava}) => App(
    socialRepository: emptySocialRepository(),
    coachRepository: silentCoachRepository(),
    purchasesRepository: FakePurchasesRepository(),
    authRepository: InMemoryAuthRepository(
      user: InMemoryAuthRepository.sampleUser,
    ),
    userRepository: users,
    workoutSessionRepository: sessions,
    nutritionRepository: InMemoryNutritionRepository(),
    bodyRepository: InMemoryBodyRepository(),
    programRepository: InMemoryProgramRepository(),
    trainingLibraryRepository: library,
    analyticsRepository: analytics,
    stravaRepository: strava,
  );

  setUp(() {
    users = InMemoryUserRepository(
      users: {uid: sampleUser(now: now)},
      settings: {uid: sampleUserSettings(now: now)},
    );
    sessions = InMemoryWorkoutSessionRepository(sessions: [workout]);
    analytics = AnalyticsRecorder();
    library = InMemoryTrainingLibraryRepository(exercises: [press]);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
  }

  Future<void> open(WidgetTester tester, {StravaRepository? strava}) async {
    tester.view
      ..physicalSize = const Size(1200, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(strava: strava));
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .go('/training/history/edit-me');
    await settle(tester);
  }

  Future<WorkoutSessionModel?> stored(WidgetTester tester) => tester
      .runAsync<WorkoutSessionModel?>(() => sessions.session(uid, 'edit-me'));

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settle(tester);
  }

  testWidgets('corrects a set, adds one, clears the notes and saves', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Felt strong'), findsOneWidget);

    await tap(tester, find.byKey(const ValueKey('session-edit')));
    // Nothing changed yet, so there is nothing to save.
    final save = find.byKey(const ValueKey('session-save'));
    expect(tester.widget<AppToolbarButton>(save).onPressed, isNull);

    // The tracker's own keypad, docked at the foot.
    await tap(tester, find.byKey(const ValueKey('cell-s1-reps')));
    await tap(tester, find.byKey(const ValueKey('keypad-1')));
    await tap(tester, find.byKey(const ValueKey('keypad-0')));
    await tap(tester, find.byKey(const ValueKey('keypad-hide')));
    expect(find.byKey(const ValueKey('keypad-1')), findsNothing);

    await tap(tester, find.text('Add Set'));
    await tester.enterText(find.byKey(const ValueKey('session-notes')), '');
    await settle(tester);

    await tap(tester, save);

    final saved = (await stored(tester))!;
    expect(saved.notes, isNull);
    expect([for (final s in saved.exercises.single.sets) s.reps], [10, 8, 8]);
    // A like is not the editor's to write.
    expect(saved.likedByUserIds, ['sample-friend-1']);
    expect(find.byKey(const ValueKey('session-edit')), findsOneWidget);
    expect(find.text('Felt strong'), findsNothing);
    expect(analytics.names, contains('SetTracker_Set_Added'));
    expect(
      analytics.names,
      containsAllInOrder([
        'WorkoutSessionDetailView_SaveChanges_Start',
        'WorkoutSessionDetailView_SaveChanges_Success',
      ]),
    );
  });

  testWidgets('throws an edit away when asked, keeping the workout', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, find.byKey(const ValueKey('session-edit')));
    await tester.enterText(
      find.byKey(const ValueKey('session-notes')),
      'Changed my mind',
    );
    await settle(tester);

    await tap(tester, find.byKey(const ValueKey('session-end-editing')));
    expect(find.text('Discard Changes?'), findsOneWidget);
    await tap(tester, find.text('Keep Editing'));
    expect(find.byKey(const ValueKey('session-save')), findsOneWidget);

    await tap(tester, find.byKey(const ValueKey('session-end-editing')));
    await tap(tester, find.text('Discard Changes'));

    expect(find.text('Felt strong'), findsOneWidget);
    expect(find.byKey(const ValueKey('session-edit')), findsOneWidget);
    expect((await stored(tester))!.notes, 'Felt strong');
  });

  testWidgets('a set that cannot be logged says why', (tester) async {
    await open(tester);
    await tap(tester, find.byKey(const ValueKey('session-edit')));
    await tap(tester, find.byKey(const ValueKey('done-s1')));
    await tap(tester, find.byKey(const ValueKey('cell-s1-reps')));
    await tap(tester, find.byKey(const ValueKey('keypad-delete')));
    await tap(tester, find.byKey(const ValueKey('keypad-hide')));

    await tap(tester, find.byKey(const ValueKey('done-s1')));

    expect(find.text('Unable to Log Set'), findsOneWidget);
  });

  testWidgets('changes the duration from its sheet; Close changes nothing', (
    tester,
  ) async {
    await open(tester);

    await tap(tester, find.text('Duration'));
    await tap(tester, find.byTooltip('Close'));
    expect(
      (await stored(tester))!.endedAt,
      yesterday.add(const Duration(minutes: 64)),
    );

    await tap(tester, find.text('Duration'));
    // The minutes wheel opens on 4; one row down is 5.
    await tester.drag(find.byType(CupertinoPicker).last, const Offset(0, -32));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save').last);
    await settle(tester);

    expect(
      (await stored(tester))!.endedAt,
      yesterday.add(const Duration(minutes: 65)),
    );
    expect(
      analytics.names,
      contains('WorkoutSessionDetailView_SaveTiming_Success'),
    );
  });

  testWidgets('moves the start from its sheet, keeping the duration', (
    tester,
  ) async {
    await open(tester);

    await tap(tester, find.text('Start Time'));
    await tap(tester, find.text('Date'));
    // The day before, from the calendar.
    final dayBefore = yesterday.subtract(const Duration(days: 1));
    if (dayBefore.month != yesterday.month) {
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('${dayBefore.day}').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save').last);
    await settle(tester);

    final saved = (await stored(tester))!;
    expect(
      saved.dateCreated.toLocal(),
      DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 7),
    );
    expect(saved.activeDuration, const Duration(minutes: 64));
  });

  testWidgets('adds an exercise from the picker', (tester) async {
    await open(tester);
    await tap(tester, find.byKey(const ValueKey('session-edit')));

    await tap(tester, find.byKey(const ValueKey('session-add-exercise')));
    await tap(tester, find.text('Aa Press').last);
    await tap(tester, find.byTooltip('Add'));

    expect(find.text('Aa Press'), findsOneWidget);
    await tap(tester, find.byKey(const ValueKey('session-save')));
    expect(
      [for (final e in (await stored(tester))!.exercises) e.name],
      ['Barbell Bench Press', 'Aa Press'],
    );
  });

  testWidgets('deletes the workout and leaves, updating the streak', (
    tester,
  ) async {
    await open(tester);

    await tap(tester, find.byKey(const ValueKey('session-more')));
    await tap(tester, find.text('Delete'));
    expect(find.text('Delete Workout?'), findsOneWidget);
    await tap(tester, find.text('Delete').last);

    expect(await stored(tester), isNull);
    expect(find.text('Push Day'), findsNothing);
    final private = await tester.runAsync(
      () => users.watchPrivateSettings(uid).first,
    );
    expect(private?.weekSessions, 0);
    expect(private?.weekStreak, 0);
    expect(
      analytics.names,
      contains('WorkoutSessionDetailView_DeleteSession_Success'),
    );
  });

  testWidgets('an edit to a workout on Strava is sent there', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final api = FakeStravaApi(
      firestore: firestore,
      uid: uid,
      athlete: const StravaAthlete(id: 7),
    );
    final strava = StravaRepository(
      firestore: firestore,
      api: api,
      sessions: sessions,
      store: InMemoryStravaAccountStore(),
      clientId: 'staging',
      uploadContext: (_) async => (
        library: const <ExerciseModel>[],
        weightUnit: WeightUnitPreference.kilograms,
        distanceUnit: DistanceUnitPreference.kilometers,
      ),
    );
    await sessions.updateStravaActivityId(uid, 'edit-me', 99);
    await open(tester, strava: strava);

    await tap(tester, find.byKey(const ValueKey('session-edit')));
    await tester.enterText(
      find.byKey(const ValueKey('session-notes')),
      'Heavy today',
    );
    await settle(tester);
    await tap(tester, find.byKey(const ValueKey('session-save')));

    expect([for (final edit in api.edits) edit.id], [99]);
    expect(api.edits.single.description, contains('Heavy today'));
    expect((await stored(tester))!.stravaActivityId, 99);
  });

  /// Chooses the menu item showing [text].
  Future<void> choose(WidgetTester tester, String text) async {
    await tester.tap(
      find
          .ancestor(
            of: find.text(text),
            matching: find.byWidgetPredicate((w) => w is PopupMenuEntry),
          )
          .last,
    );
    await settle(tester);
  }

  testWidgets('re-types a set, adds a drop, then deletes it with its drops', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, find.byKey(const ValueKey('session-edit')));

    await tap(tester, find.byKey(const ValueKey('set-type-s2')));
    await choose(tester, 'Drop Set');
    await tap(tester, find.byKey(const ValueKey('set-type-s2')));
    await choose(tester, 'Add Another Drop');
    expect(
      (await stored(tester))!.exercises.single.sets,
      hasLength(2),
      reason: 'nothing is saved until Save',
    );

    // Two drops go with it, so it asks. A finished workout runs no rests,
    // so the long press offers no Rest Timer.
    await tester.longPress(find.byKey(const ValueKey('cell-s2-reps')));
    await settle(tester);
    expect(find.text('Rest Timer…'), findsNothing);
    await tester.tap(find.text('Delete Set'));
    await settle(tester);
    expect(find.text('Delete Set 2?'), findsOneWidget);
    await tap(tester, find.text('Delete Set').last);

    await tap(tester, find.byKey(const ValueKey('session-save')));
    expect(
      [for (final set in (await stored(tester))!.exercises.single.sets) set.id],
      ['s1'],
    );
    expect(
      analytics.names,
      containsAllInOrder([
        'SetTrackerRow_SetTypeChanged',
        'SetTrackerRow_SubSetAdded',
        'SetTrackerRow_SetDeleted',
      ]),
    );
  });

  testWidgets('writes an exercise note, then deletes the exercise', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, find.byKey(const ValueKey('session-edit')));

    await tap(tester, find.byKey(const ValueKey('exercise-note-bench')));
    // The sheet's fields: this workout's note, then the exercise note.
    final fields = find.byType(EditableText);
    await tester.enterText(
      fields.at(tester.widgetList(fields).length - 2),
      'Pause reps',
    );
    await tester.enterText(fields.last, 'Elbows in');
    await tester.tap(find.text('Save').last);
    await settle(tester);
    expect(find.text('Pause reps'), findsOneWidget);
    expect(find.text('Elbows in'), findsOneWidget);
    // The exercise note is kept on the exercise now, not with the edit.
    final notes = await tester.runAsync(
      () => library.watchExerciseSettings(uid).first,
    );
    expect(notes!.single.note, 'Elbows in');

    await tap(tester, find.byKey(const ValueKey('exercise-menu-bench')));
    await choose(tester, 'Delete Exercise');
    await tap(tester, find.text('Delete Exercise').last);

    expect(find.text('Barbell Bench Press'), findsNothing);
    await tap(tester, find.byKey(const ValueKey('session-save')));
    expect((await stored(tester))!.exercises, isEmpty);
  });

  testWidgets("someone else's workout can only be read", (tester) async {
    final theirs = WorkoutSessionModel.fromFirestore({
      ...workout.toFirestore(),
      'author_id': 'sample-friend-1',
    });
    await open(tester);
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .go('/sessions/sample-friend-1/edit-me', extra: theirs);
    await settle(tester);

    expect(find.text('Push Day'), findsWidgets);
    expect(find.byKey(const ValueKey('session-edit')), findsNothing);
    expect(find.byKey(const ValueKey('session-more')), findsNothing);
    await tester.tap(find.text('Duration'));
    await settle(tester);
    expect(find.byType(CupertinoPicker), findsNothing);
  });

  testWidgets('deleting the summary closes it over the tabs', (tester) async {
    await open(tester);
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .go('/workout-summary/edit-me', extra: workout);
    await settle(tester);

    await tap(tester, find.byKey(const ValueKey('session-more')));
    await tap(tester, find.text('Delete'));
    await tap(tester, find.text('Delete').last);

    expect(await stored(tester), isNull);
    expect(find.byKey(const ValueKey('session-more')), findsNothing);
  });
}
