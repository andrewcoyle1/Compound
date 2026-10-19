import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:compound_models/compound_models.dart';
import 'package:equatable/equatable.dart';
import 'package:program_repository/program_repository.dart';

/// Where the import is.
enum ImportProgramStatus { empty, loaded, saving, saved }

/// What an unmatched name was mapped to: a library exercise, or a new one
/// of the user's, saved with the program.
final class const ImportMapping({
  required final ExerciseModel exercise,
  final bool isNew = false,
}) extends Equatable {
  @override
  List<Object?> get props => [exercise.id, isNew];
}

/// The file read, the names the library did not match and what each is
/// mapped to, its summary, and the last error.
final class const ImportProgramState({
  final ImportProgramStatus status = ImportProgramStatus.empty,
  final String? fileName,
  final ProgramFile? file,

  /// The names the library did not match, in sheet order. They stay
  /// listed once mapped.
  final List<String> reviewNames = const [],
  final Map<String, ImportMapping> mappings = const {},

  /// The nearest library names for each unmatched one.
  final Map<String, List<ExerciseModel>> suggestions = const {},
  final ProgramImportSummary? summary,

  /// A file or save error: a [ProgramImportError], or anything else.
  final Object? error,

  /// The macrocycle saved, once saved.
  final Macrocycle? saved,
}) extends Equatable {
  /// The names still to map.
  List<String> get unmappedNames => [
    for (final name in reviewNames)
      if (!mappings.containsKey(name)) name,
  ];

  /// Whether Save is allowed: a file, every name mapped, no save running.
  bool get canSave =>
      file != null &&
      status == ImportProgramStatus.loaded &&
      unmappedNames.isEmpty;

  ImportProgramState copyWith({
    ImportProgramStatus? status,
    Map<String, ImportMapping>? mappings,
    Object? Function()? error,
    Macrocycle? saved,
  }) => ImportProgramState(
    status: status ?? this.status,
    fileName: fileName,
    file: file,
    reviewNames: reviewNames,
    mappings: mappings ?? this.mappings,
    suggestions: suggestions,
    summary: summary,
    error: error == null ? this.error : error(),
    saved: saved ?? this.saved,
  );

  @override
  List<Object?> get props => [
    status,
    fileName,
    file,
    reviewNames,
    mappings,
    suggestions,
    summary,
    error,
    saved,
  ];
}

/// Import Program (Swift `ImportProgramPresenter`): read a file, list the
/// names the library did not match, map them (a suggestion, one from the
/// library, or a new exercise), then save. Nothing is written until Save:
/// new exercises first, then the mesocycles, then the macrocycle, not
/// started.
class ImportProgramCubit extends Cubit<ImportProgramState> {
  /// Imports for the user `uid` against `library`, the exercises names are
  /// matched to. `labels` name what a sheet leaves unnamed.
  new({
    required this._uid,
    required this._library,
    required this._labels,
    required this._setup,
    required this._analytics,
    this._now = DateTime.now,
    this._newId = newDocumentId,
  }) : _matcher = ExerciseNameMatcher(_library),
       super(const ImportProgramState()) {
    _analytics.appear(_screen);
  }

  static const _screen = 'ImportProgramView';

  final String _uid;
  final List<ExerciseModel> _library;
  final ProgramSheetLabels _labels;
  final TrainingSetupService _setup;
  final AnalyticsRepository _analytics;
  final DateTime Function() _now;
  final String Function() _newId;
  final ExerciseNameMatcher _matcher;

  /// Reads the file [name] (its extension decides the format), lists what
  /// needs mapping and summarises it from a trial build, so a sheet whose
  /// weeks disagree is reported now rather than at Save.
  void fileChosen(String name, List<int> bytes) {
    final dot = name.lastIndexOf('.');
    final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    final fileName = dot < 0 ? name : name.substring(0, dot);
    try {
      final file = readProgramFile(bytes, extension, labels: _labels);
      final review = switch (file) {
        ProgramFileSheet(:final sheet) => unmatchedProgramNames(
          sheet,
          _matcher.match,
        ),
        ProgramFileMesocycles() => const <String>[],
      };
      final loaded = ImportProgramState(
        status: ImportProgramStatus.loaded,
        fileName: fileName,
        file: file,
        reviewNames: review,
        suggestions: {
          for (final name in review) name: _matcher.suggestions(name),
        },
      );
      emit(
        ImportProgramState(
          status: loaded.status,
          fileName: fileName,
          file: file,
          reviewNames: review,
          suggestions: loaded.suggestions,
          summary: ProgramImportSummary.of(
            _build(loaded, stubUnmatched: true).mesocycles,
          ),
        ),
      );
      _analytics.analytic('${_screen}_File_Loaded', {
        'format': extension,
        'unmatched_count': review.length,
      });
    } on Object catch (error) {
      _analytics.severe('${_screen}_File_Fail', error);
      emit(ImportProgramState(error: error));
    }
  }

  /// Maps [name] to the suggested [exercise].
  void suggestionPressed(String name, ExerciseModel exercise) {
    _analytics.analytic('${_screen}_UseSuggestion');
    _map(name, ImportMapping(exercise: exercise));
  }

  /// Records that the library picker was opened for a name.
  void chooseFromLibraryPressed() =>
      _analytics.analytic('${_screen}_ChooseFromLibrary');

  /// Maps [name] to [exercise], picked from the library.
  void libraryExerciseChosen(String name, ExerciseModel exercise) =>
      _map(name, ImportMapping(exercise: exercise));

  /// Maps [name] to a new exercise of the user's.
  void createPressed(String name) {
    _analytics.analytic('${_screen}_CreateExercise');
    final sheet = switch (state.file) {
      ProgramFileSheet(:final sheet) => sheet,
      _ => null,
    };
    _map(
      name,
      ImportMapping(
        exercise: _setup.newImportedExercise(
          _uid,
          name,
          perSide: sheet != null && isPerSideInSheet(sheet, name),
        ),
        isNew: true,
      ),
    );
  }

  void _map(String name, ImportMapping mapping) =>
      emit(state.copyWith(mappings: {...state.mappings, name: mapping}));

  /// Builds the program and saves it in order.
  Future<void> save() async {
    if (!state.canSave) return;
    emit(state.copyWith(status: ImportProgramStatus.saving, error: () => null));
    _analytics.analytic('${_screen}_Save_Start');
    try {
      final result = _build(state);
      await _setup.saveImportedProgram(
        result,
        created: [
          for (final name in state.reviewNames)
            if (state.mappings[name] case ImportMapping(
              :final exercise,
              isNew: true,
            ))
              exercise,
        ],
      );
      _analytics.analytic('${_screen}_Save_Success', {
        'mesocycle_count': result.mesocycles.length,
      });
      emit(
        state.copyWith(
          status: ImportProgramStatus.saved,
          saved: result.macrocycle,
        ),
      );
    } on Object catch (error) {
      _analytics.severe('${_screen}_Save_Fail', error);
      emit(
        state.copyWith(status: ImportProgramStatus.loaded, error: () => error),
      );
    }
  }

  /// The program [state]'s file makes. A trial build stands a new
  /// exercise in for each name still unmatched.
  ProgramImportResult _build(
    ImportProgramState state, {
    bool stubUnmatched = false,
  }) {
    final style = ProgramImportStyle(
      authorId: _uid,
      icon: mesocycleIcons.first,
      colour: mesocycleColours.first,
    );
    return switch (state.file!) {
      ProgramFileSheet(:final sheet) => buildProgramFromSheet(
        sheet,
        style: style,
        now: _now(),
        newId: _newId,
        resolve: (name) =>
            state.mappings[name]?.exercise ??
            _matcher.match(name) ??
            (stubUnmatched
                ? _setup.newImportedExercise(_uid, name, perSide: false)
                : null),
      ),
      ProgramFileMesocycles(:final mesocycles) => buildProgramFromMesocycles(
        mesocycles,
        title: state.fileName ?? '',
        style: style,
        library: _library,
        now: _now(),
        newId: _newId,
      ),
    };
  }

  @override
  Future<void> close() {
    _analytics.disappear(_screen);
    return super.close();
  }
}
