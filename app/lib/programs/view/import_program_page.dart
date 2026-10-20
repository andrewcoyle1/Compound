import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/import_program_cubit.dart';
import 'package:compound/training_library/bloc/training_library_bloc.dart';
import 'package:compound/training_library/models/training_library.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound_models/compound_models.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:program_repository/program_repository.dart';

/// Picks a program file; its name and bytes, or null when cancelled.
typedef ProgramFilePicker = Future<(String, List<int>)?> Function();

/// The platform's document picker, for `.xlsx`, `.csv` and `.json`.
Future<(String, List<int>)?> pickProgramFile() async {
  final file = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(
        label: 'Programs',
        extensions: ['xlsx', 'csv', 'json'],
        mimeTypes: [
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'text/csv',
          'text/comma-separated-values',
          'application/json',
        ],
        uniformTypeIdentifiers: [
          'org.openxmlformats.spreadsheetml.sheet',
          'public.comma-separated-values-text',
          'public.json',
        ],
      ),
    ],
  );
  return file == null ? null : (file.name, await file.readAsBytes());
}

/// Import Program (Swift `ImportProgramView`): a spreadsheet, CSV or the
/// app's JSON becomes mesocycles in a macrocycle that has not started.
/// Pops with that macrocycle once saved.
class const ImportProgramPage({
  final ProgramFilePicker pickFile = pickProgramFile,
  super.key,
}) extends StatelessWidget {
  /// The path under the Training tab.
  static const path = 'import-program';

  /// The route name.
  static const name = 'importProgram';

  /// Opens the importer; the macrocycle saved, or null.
  static Future<Macrocycle?> open(BuildContext context) =>
      context.pushNamed<Macrocycle>(name);

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    final l10n = context.l10n;
    return TrainingLibraryProvider(
      uid: app.user.uid,
      child: BlocBuilder<TrainingLibraryBloc, TrainingLibraryState>(
        buildWhen: (previous, current) =>
            previous.runtimeType != current.runtimeType,
        builder: (context, library) => switch (library) {
          TrainingLibraryLoaded(:final library) => BlocProvider(
            create: (context) {
              return ImportProgramCubit(
                uid: app.user.uid,
                library: library.allExercises,
                labels: ProgramSheetLabels(
                  firstWeek: l10n.importFirstWeek,
                  firstDay: l10n.importFirstDay,
                  untitled: l10n.importUntitled,
                ),
                setup: context.read<TrainingSetupService>(),
                analytics: context.read<AnalyticsRepository>(),
              );
            },
            child: ImportProgramView(
              pickFile: pickFile,
              library: library.allExercises,
            ),
          ),
          _ => const AppScaffold(body: Center(child: AppSpinner())),
        },
      ),
    );
  }
}

class const ImportProgramView({
  required final ProgramFilePicker pickFile,
  required final List<ExerciseModel> library,
  super.key,
}) extends StatelessWidget {
  Future<void> _choose(BuildContext context) async {
    final cubit = context.read<ImportProgramCubit>();
    final picked = await pickFile();
    if (picked case (final name, final bytes)) cubit.fileChosen(name, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ImportProgramCubit>().state;
    final cubit = context.read<ImportProgramCubit>();
    final error = state.error;
    final summary = state.summary;
    final hasFile = state.file != null;
    return BlocListener<ImportProgramCubit, ImportProgramState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case ImportProgramStatus.saved:
            unawaited(AppHaptics.success());
            context.pop(state.saved);
          case ImportProgramStatus.loaded when state.error != null:
            unawaited(AppHaptics.error());
          case _:
        }
      },
      // A file read is not swiped away; Close still closes.
      child: PopScope(
        canPop: !hasFile,
        child: AppScaffold(
          appBar: AppBar(
            leading: AppToolbarButton.close(
              semanticLabel: MaterialLocalizations.of(context)
                  .closeButtonTooltip,
              onPressed: () => context.pop(),
            ),
            title: Text(l10n.importTitle),
          ),
          body: SafeArea(
            bottom: false,
            child: !hasFile && error == null
                ? AppEmptyState(
                    icon: AppSymbols.mesocycle,
                    title: l10n.importTitle,
                    description: l10n.importFormats,
                    actionLabel: l10n.importChooseFile,
                    onAction: () => unawaited(_choose(context)),
                  )
                : LibrarySections(
                    children: [
                      if (error != null)
                        AppInlineMessage(
                          kind: AppInlineMessageKind.error,
                          kindLabel: l10n.importFailed,
                          text: importErrorMessage(l10n, error),
                        ),
                      AppSection(
                        children: [
                          AppListRowButton(
                            title: state.fileName ?? l10n.importChooseFile,
                            subtitle: state.fileName == null
                                ? null
                                : l10n.importChooseFile,
                            onPressed: () => unawaited(_choose(context)),
                          ),
                        ],
                      ),
                      if (state.reviewNames.isNotEmpty)
                        AppSection(
                          header: l10n.importUnmatchedHeader,
                          footer: l10n.importUnmatchedFooter,
                          children: [
                            for (final name in state.reviewNames)
                              _UnmatchedRow(
                                name: name,
                                state: state,
                                onChooseFromLibrary: () async {
                                  cubit.chooseFromLibraryPressed();
                                  final chosen = await _chooseFromLibrary(
                                    context,
                                    name,
                                  );
                                  if (chosen != null) {
                                    cubit.libraryExerciseChosen(name, chosen);
                                  }
                                },
                              ),
                          ],
                        ),
                      if (summary != null) _Summary(summary),
                    ],
                  ),
          ),
          bottomNavigationBar: AppBottomCta(
            children: [
              if (hasFile)
                AppCtaButton(
                  label: l10n.importSave,
                  isLoading: state.status == ImportProgramStatus.saving,
                  onPressed: state.canSave
                      ? () => unawaited(cubit.save())
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The library as a one-tap picker, its search already holding [name].
  Future<ExerciseModel?> _chooseFromLibrary(
    BuildContext context,
    String name,
  ) => showAppSheet<ExerciseModel>(
    context: context,
    size: AppSheetSize.full,
    builder: (_) => _LibraryPicker(library: library, initialQuery: name),
  );
}

/// The message for an import [error], "Row 12: …" where it has a row.
String importErrorMessage(AppLocalizations l10n, Object error) {
  final message = switch (error) {
    UnreadableFileError() => l10n.importErrorUnreadable,
    NoHeaderRowError() => l10n.importErrorNoHeader,
    NoExercisesError() => l10n.importErrorNoExercises,
    MissingWorkingSetsError() => l10n.importErrorWorkingSets,
    DaysDifferError(:final week) => l10n.importErrorDaysDiffer(week),
    ExercisesDifferError(:final week, :final day) =>
      l10n.importErrorExercisesDiffer(week, day),
    UnmatchedExercisesError(:final names) => l10n.importErrorUnmatched(
      names.join(', '),
    ),
    _ => l10n.programTryAgain,
  };
  return switch (error) {
    ProgramImportError(:final row?) => l10n.importErrorRow(row, message),
    _ => message,
  };
}

/// The display name of a set type (Swift `SetTargetSetType.name`).
String setTypeName(AppLocalizations l10n, SetTargetSetType type) =>
    switch (type) {
      SetTargetSetType.standard => l10n.setTypeStandard,
      SetTargetSetType.drop => l10n.setTypeDrop,
      SetTargetSetType.myo => l10n.setTypeMyo,
      SetTargetSetType.failure || SetTargetSetType.amrap => l10n.setTypeFailure,
      SetTargetSetType.restPause => l10n.setTypeRestPause,
      SetTargetSetType.cluster => l10n.setTypeCluster,
      SetTargetSetType.partials => l10n.setTypePartials,
      SetTargetSetType.stretch => l10n.setTypeStretch,
      SetTargetSetType.hold => l10n.setTypeHold,
    };

/// An unmatched name: what it is mapped to, else the suggestions, else
/// "Not matched", with a menu of the suggestions, the library and Create.
class const _UnmatchedRow({
  required final String name,
  required final ImportProgramState state,
  required final Future<void> Function() onChooseFromLibrary,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ImportProgramCubit>();
    final mapping = state.mappings[name];
    final suggestions = state.suggestions[name] ?? const <ExerciseModel>[];
    final subtitle = switch (mapping) {
      ImportMapping(isNew: true) => l10n.importNewExercise,
      ImportMapping(:final exercise) => exercise.name,
      null when suggestions.isNotEmpty => l10n.importSuggested(
        _orList(l10n, [for (final s in suggestions) s.name]),
      ),
      null => l10n.importNotMatched,
    };
    return PopupMenuButton<VoidCallback>(
      onSelected: (action) => action(),
      itemBuilder: (_) => [
        for (final exercise in suggestions)
          PopupMenuItem(
            value: () {
              unawaited(AppHaptics.selection());
              cubit.suggestionPressed(name, exercise);
            },
            child: Text(l10n.importUseSuggestion(exercise.name)),
          ),
        if (suggestions.isNotEmpty) const PopupMenuDivider(),
        PopupMenuItem(
          value: () => unawaited(onChooseFromLibrary()),
          child: Text(l10n.importChooseFromLibrary),
        ),
        PopupMenuItem(
          value: () {
            unawaited(AppHaptics.selection());
            cubit.createPressed(name);
          },
          child: Text(l10n.importCreateExercise(name)),
        ),
      ],
      child: AppListRow(
        title: name,
        subtitle: subtitle,
        accessory: AppListRowCheckmark(selected: mapping != null),
      ),
    );
  }

  /// "A, B or C".
  static String _orList(AppLocalizations l10n, List<String> names) =>
      names.length < 2
      ? names.join()
      : '${names.sublist(0, names.length - 1).join(', ')} '
            '${l10n.importOr} ${names.last}';
}

/// What the file holds.
class const _Summary(final ProgramImportSummary summary)
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final techniques = [
      for (final type in summary.techniques) setTypeName(l10n, type),
    ]..sort();
    return AppSection(
      header: l10n.importSummary,
      footer: l10n.importSummaryFooter,
      children: [
        AppListRow(title: l10n.importBlocks(summary.blocks)),
        AppListRow(title: l10n.streakWeeks(summary.weeks)),
        AppListRow(title: l10n.importDays(summary.days)),
        AppListRow(title: l10n.exerciseCount(summary.exercises)),
        if (techniques.isNotEmpty)
          AppListRow(
            title: l10n.importTechniques,
            subtitle: techniques.toSet().join(', '),
          ),
        AppListRow(
          title: l10n.importWarmups,
          accessory: AppListRowValue(
            l10n.importCountOf(summary.withWarmups, summary.exercises),
          ),
        ),
        AppListRow(
          title: l10n.importRest,
          accessory: AppListRowValue(
            l10n.importCountOf(summary.withRest, summary.exercises),
          ),
        ),
      ],
    );
  }
}

/// The library, searchable, as a one-tap picker.
class const _LibraryPicker({
  required final List<ExerciseModel> library,
  required final String initialQuery,
}) extends StatefulWidget {
  @override
  State<_LibraryPicker> createState() => _LibraryPickerState();
}

class _LibraryPickerState extends State<_LibraryPicker> {
  late String _query = widget.initialQuery;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Any word of the imported name may find it, the closest first.
    final matches = FuzzyMatch.search(
      TrainingLibrary.byName(widget.library, (exercise) => exercise.name),
      _query,
      (exercise) => [
        [exercise.name],
      ],
      anyWord: true,
    );
    return AppScaffold(
      appBar: AppBar(
        leading: AppToolbarButton.close(
          semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
        ),
        title: Text(l10n.importChooseFromLibrary),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: AppSearchField(
              clearLabel: l10n.clearSearch,
              hint: l10n.trainingSearchHint,
              initialValue: widget.initialQuery,
              onChanged: (query) => setState(() => _query = query),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final exercise in matches)
                  AppListRowButton(
                    title: exercise.name,
                    onPressed: () => Navigator.of(context).pop(exercise),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
