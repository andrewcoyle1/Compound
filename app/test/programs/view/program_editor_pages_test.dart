import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/programs.dart';
import 'package:compound/programs/view/import_program_page.dart';
import 'package:compound/training/training.dart';
import 'package:compound/training_library/training_library.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../helpers/helpers.dart';
import '../helpers.dart';

/// The Training tab with the program routes; or, given [pickFile], a
/// home screen that opens the importer with that picker.
GoRouter _router(String location, {ProgramFilePicker? pickFile}) => GoRouter(
  initialLocation: location,
  routes: [
    if (pickFile != null)
      GoRoute(
        path: '/home',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final saved = await ImportProgramPage.open(context);
                if (context.mounted && saved != null) {
                  showAppSnackBar(context, 'Imported ${saved.name}');
                }
              },
              child: const Text('Open importer'),
            ),
          ),
        ),
        routes: [
          GoRoute(
            path: ImportProgramPage.path,
            name: ImportProgramPage.name,
            builder: (_, _) => ImportProgramPage(pickFile: pickFile),
          ),
        ],
      )
    else
      GoRoute(
        path: '/training',
        builder: (_, _) => const TrainingPage(),
        routes: [
          ...programRoutes,
          GoRoute(
            path: WorkoutsPage.path,
            name: WorkoutsPage.name,
            builder: (_, _) => const Text('Workouts screen'),
            routes: [
              GoRoute(
                path: WorkoutTemplateDetailPage.path,
                name: WorkoutTemplateDetailPage.name,
                builder: (_, state) =>
                    WorkoutTemplateDetailPage.fromRoute(state),
              ),
            ],
          ),
          GoRoute(
            path: ExercisesPage.path,
            name: ExercisesPage.name,
            builder: (_, _) => const Text('Exercises screen'),
          ),
          GoRoute(
            path: 'history',
            name: 'workoutHistory',
            builder: (_, _) => const Text('History screen'),
          ),
        ],
      ),
  ],
);

Future<T> _read<T>(WidgetTester tester, Future<T> Function() read) async =>
    (await tester.runAsync(read)) as T;

List<int> _fixture(String name) =>
    File('../contracts/fixtures/programs/$name').readAsBytesSync();

void main() {
  late AppBloc appBloc;
  final m1 = programMesocycle('m1');
  final m2 = programMesocycle('m2');

  setUp(() {
    appBloc = MockAppBloc();
    when(() => appBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => appBloc.state).thenReturn(
      const AppAuthenticated(AuthUser(uid: programUid, isAnonymous: false)),
    );
  });

  Future<ProgramWorld> pump(
    WidgetTester tester,
    String location, {
    ProgramFilePicker? pickFile,
    InMemoryTrainingLibraryRepository? library,
  }) async {
    tester.view
      ..physicalSize = const Size(1200, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final world = ProgramWorld.seeded(
      mesocycles: [m1, m2],
      macrocycles: [
        programMacrocycle('p', ['m1']),
      ],
      active: 'm1',
    );
    await tester.pumpApp(
      const SizedBox(),
      appBloc: appBloc,
      router: _router(location, pickFile: pickFile),
      programRepository: world.programs,
      userRepository: world.users,
      workoutSessionRepository: world.sessions,
      trainingLibraryRepository: library,
      analyticsRepository: world.analytics,
      programsCubit: world.cubit()..userChanged(programUid),
    );
    await tester.pumpAndSettle();
    return world;
  }

  Future<List<Mesocycle>> mesocycles(WidgetTester tester, ProgramWorld w) =>
      _read(tester, () => w.programs.watchMesocycles(programUid).first);

  group('create flow', () {
    testWidgets('names, styles and lays out a new mesocycle', (tester) async {
      final world = await pump(tester, '/training/create-mesocycle');
      expect(find.text('Create Mesocycle'), findsOneWidget);

      final continueButton = find.byKey(const Key('NameProgram.continue'));
      final nameField = find.byKey(const Key('NameProgram.name'));
      expect(
        find.text(DateTime.now().toIso8601String().substring(0, 10)),
        findsOneWidget,
      );
      await tester.enterText(nameField, '   ');
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Choose an icon for this mesocycle.'), findsNothing);

      await tester.enterText(nameField, '  Hypertrophy  ');
      await tester.pump();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Choose an icon for this mesocycle.'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Green'));
      await tester.tap(find.bySemanticsLabel('Sailboat'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ProgramIcon.continue')));
      await tester.pumpAndSettle();

      // One rest day, which cannot be saved or activated.
      expect(find.text('Rest'), findsWidgets);
      await tester.tap(find.text('Save Mesocycle'));
      await tester.pumpAndSettle();
      expect(await mesocycles(tester, world), hasLength(2));

      await tester.tap(find.text('Add Day'));
      await tester.pumpAndSettle();
      // Two day buttons, and the selected rest day's own section.
      expect(find.text('Rest Day'), findsNWidgets(3));
      expect(
        world.analytics.names,
        containsAllInOrder([
          'NameProgramView_Appear',
          'ProgramIconView_Appear',
          'ProgramDesignView_Appear',
        ]),
      );

      // Back steps to the icon.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Choose an icon for this mesocycle.'), findsOneWidget);
    });

    testWidgets('close ends the flow', (tester) async {
      await pump(tester, '/training');
      await tester.tap(find.byTooltip('Add training'));
      await tester.pumpAndSettle();
      expect(find.text('Start Empty Workout'), findsWidgets);
      expect(find.text('New Macrocycle'), findsOneWidget);
      await tester.tap(find.text('New Mesocycle'));
      await tester.pumpAndSettle();
      expect(find.text('Mesocycle Name'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Mesocycle Name'), findsNothing);
      expect(find.text('Active Mesocycle'), findsOneWidget);
    });
  });

  group('editor', () {
    testWidgets('renames a day, and asks before losing it', (tester) async {
      await pump(tester, '/training/edit-mesocycle/m2');
      expect(find.text('Edit Mesocycle'), findsOneWidget);
      expect(find.text('Activate Mesocycle'), findsOneWidget);
      expect(find.text('Upper'), findsOneWidget);
      expect(find.text('Bench'), findsOneWidget);

      await tester.tap(find.text('Lower'));
      await tester.pumpAndSettle();
      expect(find.text('Squat'), findsOneWidget);

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(find.text('Rename Day'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Rename Day'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Legs  ');
      await tester.pump();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Legs'), findsOneWidget);

      await tester.tap(find.byKey(const Key('ProgramDesign.close')));
      await tester.pumpAndSettle();
      expect(find.text('Discard Changes?'), findsOneWidget);
      await tester.tap(find.text('Discard Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Mesocycle'), findsNothing);
    });

    testWidgets('removes a day and saves', (tester) async {
      final world = await pump(tester, '/training/edit-mesocycle/m2');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ProgramDesign.save')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Mesocycle'), findsNothing);
      final saved = (await mesocycles(
        tester,
        world,
      )).firstWhere((m) => m.id == 'm2');
      expect(
        [for (final d in saved.workoutTemplates) d.name],
        ['Rest Day', 'Lower'],
      );
    });

    testWidgets('an unchanged editor closes at once', (tester) async {
      await pump(tester, '/training');
      await tester.tap(find.byTooltip('Workout options').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Info'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Mesocycle'), findsOneWidget);
      // The active mesocycle is not activated again.
      expect(find.text('Activate Mesocycle'), findsNothing);

      await tester.tap(find.byKey(const Key('ProgramDesign.close')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Mesocycle'), findsNothing);
    });

    testWidgets('deletes the mesocycle from its menu', (tester) async {
      final world = await pump(tester, '/training/edit-mesocycle/m2');
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete Mesocycle'));
      await tester.pumpAndSettle();
      expect(
        find.text("“Block m2” will be deleted. This can't be undone."),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete Mesocycle').last);
      await tester.pumpAndSettle();

      expect(find.text('Edit Mesocycle'), findsNothing);
      expect([for (final m in await mesocycles(tester, world)) m.id], ['m1']);
    });

    testWidgets('a missing mesocycle shows an empty state', (tester) async {
      await pump(tester, '/training/edit-mesocycle/gone');
      expect(find.text('No Mesocycles'), findsOneWidget);
    });

    testWidgets("a day's exercise opens its targets", (tester) async {
      await pump(tester, '/training/edit-mesocycle/m2');
      await tester.tap(find.text('Bench'));
      await tester.pumpAndSettle();
      expect(find.text('Targets'), findsOneWidget);
    });
  });

  group('settings', () {
    testWidgets('edits every setting in place and activates', (tester) async {
      final world = await pump(tester, '/training/edit-mesocycle/m2');
      await tester.tap(find.byTooltip('Mesocycle settings'));
      await tester.pumpAndSettle();
      expect(find.text('Mesocycle Settings'), findsOneWidget);
      expect(find.text('Upper, Rest Day, Lower'), findsOneWidget);
      expect(find.text('2 cycles'), findsOneWidget);

      // Name.
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Block Two');
      await tester.pump();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Block Two'), findsWidgets);

      // Cycles.
      await tester.tap(find.byTooltip('More cycles'));
      await tester.pump();
      expect(find.text('3 cycles'), findsOneWidget);
      await tester.tap(find.byTooltip('Fewer cycles'));
      await tester.pump();
      await tester.tap(find.byTooltip('Fewer cycles'));
      await tester.pump();
      expect(find.text('1 cycle'), findsOneWidget);

      // Colour and icon.
      await tester.tap(find.text('Color & Icon'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Purple').last);
      await tester.tap(find.bySemanticsLabel('Gauge').last);
      await tester.pump();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      // Day order: Lower to the top.
      await tester.tap(find.text('Day Order'));
      await tester.pumpAndSettle();
      // Dropping Lower first, as the list reports a drag.
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(2, 0);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Lower, Upper, Rest Day'), findsOneWidget);

      // Deload; Close keeps the old one.
      await tester.tap(find.text('Deload'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last Cycle'));
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('None'), findsOneWidget);
      await tester.tap(find.text('Deload'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Last Cycle'));
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Last Cycle'), findsOneWidget);

      await tester.tap(find.text('Periodization'));
      await tester.pump();

      await tester.tap(find.text('Activate Mesocycle'));
      await tester.pumpAndSettle();
      expect(find.text('Mesocycle Settings'), findsNothing);
      expect(find.text('Edit Mesocycle'), findsOneWidget);

      final saved = (await mesocycles(
        tester,
        world,
      )).firstWhere((m) => m.id == 'm2');
      expect(saved.name, 'Block Two');
      expect(saved.numMicrocycles, 1);
      expect(saved.colour, '#AF52DE');
      expect(saved.icon, 'gauge.with.dots.needle.bottom.100percent');
      expect(saved.deload, DeloadType.end);
      expect(saved.periodisation, isTrue);
      expect(saved.workoutTemplates.first.name, 'Lower');
      expect(
        world.analytics.names,
        containsAllInOrder([
          'ProgramSettingsView_Appear',
          'RenameWorkoutTemplateModelView_Appear',
          'EditMesocycleColourIconView_Appear',
          'EditDayOrderView_Appear',
          'EditDeloadView_Appear',
          'ProgramSettingsView_Activate_Success',
        ]),
      );
    });
  });

  group('library and macrocycles', () {
    testWidgets('the library offers create, import and edit', (tester) async {
      await pump(tester, '/training/mesocycles');
      await tester.tap(find.byTooltip('Add mesocycle'));
      await tester.pumpAndSettle();
      expect(find.text('Import Program…'), findsOneWidget);
      await tester.tap(find.text('Create Mesocycle'));
      await tester.pumpAndSettle();
      expect(find.text('Mesocycle Name'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Workout options').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Mesocycle'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Mesocycle'), findsOneWidget);
    });

    testWidgets('macrocycles offer an import', (tester) async {
      await pump(tester, '/training/macrocycles');
      await tester.tap(find.byTooltip('Add macrocycle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import Program…'));
      await tester.pumpAndSettle();
      expect(find.text('Spreadsheet, CSV or JSON'), findsOneWidget);
    });
  });

  group('template detail', () {
    testWidgets('a day of the user mesocycle edits it or saves a copy', (
      tester,
    ) async {
      final library = InMemoryTrainingLibraryRepository();
      await pump(tester, '/training/workouts/upper', library: library);
      await tester.tap(find.byTooltip('Workout options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save a Copy to Workouts'));
      await tester.pumpAndSettle();
      expect(find.text('Saved Upper to your workouts'), findsOneWidget);

      await tester.tap(find.byTooltip('Workout options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Mesocycle'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Mesocycle'), findsOneWidget);
    });
  });

  group('import', () {
    Future<void> openImporter(
      WidgetTester tester,
      ProgramFilePicker pickFile,
    ) async {
      await pump(
        tester,
        '/home',
        pickFile: pickFile,
        library: InMemoryTrainingLibraryRepository(),
      );
      await tester.tap(find.text('Open importer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a file'));
      await tester.pumpAndSettle();
    }

    testWidgets('a sheet lists its unmatched names and summary', (
      tester,
    ) async {
      await openImporter(
        tester,
        () async => ('sample-program.csv', _fixture('sample-program.csv')),
      );
      expect(find.text('sample-program'), findsOneWidget);
      expect(find.text('Unmatched exercises'), findsOneWidget);
      expect(find.text('2 blocks'), findsOneWidget);
      expect(find.text('4 weeks'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<VoidCallback>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Create "'));
      await tester.pumpAndSettle();
      expect(find.text('New exercise'), findsOneWidget);
    });

    testWidgets('a name is chosen from the library', (tester) async {
      await openImporter(
        tester,
        () async => ('sample-program.csv', _fixture('sample-program.csv')),
      );
      await tester.tap(find.text('Squat').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Barbell Squat').last);
      await tester.pumpAndSettle();
      expect(find.text('Barbell Squat'), findsOneWidget);
    });

    testWidgets('JSON saves and hands back its macrocycle', (tester) async {
      await openImporter(
        tester,
        () async => ('sample-program.json', _fixture('sample-program.json')),
      );
      await tester.tap(find.text('Save Program'));
      await tester.pumpAndSettle();
      expect(find.text('Imported sample-program'), findsOneWidget);
    });

    testWidgets('an error names its row', (tester) async {
      const csv =
          'Day,Exercise,Working Sets\nWeek 1\nPush,Squat,3\n'
          'Week 2\nPush,Leg Curl,3\n';
      await openImporter(tester, () async => ('plan.csv', utf8.encode(csv)));
      expect(
        find.text('Row 5: Week 2, Push: the exercises differ from week 1.'),
        findsOneWidget,
      );
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      await openImporter(tester, () async => null);
      expect(find.text('Spreadsheet, CSV or JSON'), findsOneWidget);
    });
  });

  test('import errors are worded', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      importErrorMessage(l10n, const UnreadableFileError()),
      'This file could not be read as a program.',
    );
    expect(
      importErrorMessage(l10n, const NoHeaderRowError()),
      'No header row with an "Exercise" column was found.',
    );
    expect(
      importErrorMessage(l10n, const NoExercisesError()),
      'The file has no exercises.',
    );
    expect(
      importErrorMessage(l10n, const MissingWorkingSetsError(3)),
      'Row 3: Working sets is missing or not a number.',
    );
    expect(
      importErrorMessage(l10n, const DaysDifferError('Week 2', 9)),
      'Row 9: Week 2 has different days from week 1.',
    );
    expect(
      importErrorMessage(l10n, const UnmatchedExercisesError(['A', 'B'])),
      'Match these exercises first: A, B',
    );
    expect(importErrorMessage(l10n, StateError('x')), 'Please try again.');
    expect([
      for (final t in SetTargetSetType.values) setTypeName(l10n, t),
    ], everyElement(isNotEmpty));
  });
}
