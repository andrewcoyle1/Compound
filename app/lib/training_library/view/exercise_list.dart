import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/bloc/training_library_bloc.dart';
import 'package:compound/training_library/cubit/exercise_list_cubit.dart';
import 'package:compound/training_library/logic/exercise_filters.dart';
import 'package:compound/training_library/logic/search_match.dart';
import 'package:compound/training_library/models/training_library.dart';
import 'package:compound/training_library/view/exercise_image.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The exercise library as a list: a search field, the filter bar, then the
/// user's exercises and the bundled ones, or the search results (Swift
/// `ExerciseListBuilderView`). The library and the picker both show it.
///
/// Needs a [TrainingLibraryBloc] and an [ExerciseListCubit] above it.
class ExerciseList extends StatelessWidget {
  const new({
    required this.onExercisePressed,
    this.isSelected,
    this.onCreateExercise,
    super.key,
  });

  /// A row was tapped.
  final ValueChanged<ExerciseModel> onExercisePressed;

  /// Whether an exercise shows ticked; null shows no selection at all.
  final bool Function(ExerciseModel)? isSelected;

  /// Opens Create Exercise from the end of Custom Exercises; null leaves
  /// the row out.
  final VoidCallback? onCreateExercise;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final onCreateExercise = this.onCreateExercise;
    final libraryState = context.watch<TrainingLibraryBloc>().state;
    final listState = context.watch<ExerciseListCubit>().state;
    final header = [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          0,
        ),
        child: AppSearchField(
          clearLabel: l10n.clearSearch,
          hint: l10n.exercisesSearchHint,
          onChanged: context.read<ExerciseListCubit>().queryChanged,
        ),
      ),
      if (libraryState case TrainingLibraryLoaded(:final library))
        _FilterBar(library: library, filters: listState.filters),
    ];
    final body = switch (libraryState) {
      TrainingLibraryLoading() => const Center(
        child: CircularProgressIndicator.adaptive(),
      ),
      TrainingLibraryFailure() => LibraryFailure(
        message: l10n.exercisesLoadFailure,
        onRetry: () => context.read<TrainingLibraryBloc>().add(
          const TrainingLibrarySubscriptionRequested(),
        ),
      ),
      TrainingLibraryLoaded(:final library) => _Sections(
        library: library,
        state: listState,
        onExercisePressed: (exercise) {
          context.read<ExerciseListCubit>().exerciseSelected(exercise);
          onExercisePressed(exercise);
        },
        isSelected: isSelected,
        onCreateExercise: onCreateExercise == null
            ? null
            : () {
                context.read<ExerciseListCubit>().addExercisePressed();
                onCreateExercise();
              },
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...header,
        Expanded(child: body),
      ],
    );
  }
}

class _Sections extends StatelessWidget {
  const new({
    required this.library,
    required this.state,
    required this.onExercisePressed,
    required this.isSelected,
    required this.onCreateExercise,
  });

  final TrainingLibrary library;
  final ExerciseListState state;
  final ValueChanged<ExerciseModel> onExercisePressed;
  final bool Function(ExerciseModel)? isSelected;
  final VoidCallback? onCreateExercise;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filters = state.filters;
    final List<Widget> children;
    if (SearchMatch.isSearching(state.query)) {
      final results = library.filtered(
        library.searchExercises(state.query),
        filters,
      );
      children = results.isEmpty
          ? [
              LibraryEmptyState(
                icon: AppSymbols.search,
                title: l10n.searchNoResults(state.query.trim()),
                message: l10n.searchNoResultsMessage,
              ),
            ]
          : [AppSection(children: _rows(results))];
    } else {
      final mine = library.filtered(library.userExercises, filters);
      final official = library.filtered(library.systemExercises, filters);
      final onCreateExercise = this.onCreateExercise;
      children = [
        AppSection(
          header: l10n.exercisesCustomHeader,
          children: [
            // First, as Swift's + in the section header.
            if (onCreateExercise != null)
              AppListRowButton(
                key: const Key('ExerciseList.create'),
                title: l10n.createExerciseRow,
                icon: AppSymbols.add,
                onPressed: onCreateExercise,
              ),
            if (mine.isEmpty)
              LibraryEmptyState(
                icon: AppSymbols.exercise,
                title: l10n.exercisesNoCustomTitle,
                message: l10n.exercisesNoCustomMessage,
              )
            else
              ..._rows(mine),
          ],
        ),
        if (official.isNotEmpty)
          AppSection(
            header: l10n.exercisesOfficialHeader,
            children: _rows(official),
          ),
        // A filter can empty both sections, and bare headers explain
        // nothing.
        if (filters.isActive && mine.isEmpty && official.isEmpty)
          LibraryEmptyState(
            icon: AppSymbols.filter,
            title: l10n.exercisesNoMatchesTitle,
            message: l10n.exercisesNoMatchesMessage,
          ),
      ];
    }
    // ponytail: each section is one non-lazy column (136 bundled rows);
    // switch to a sliver list if the library grows past a few hundred.
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.l),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.xl),
          child,
        ],
      ],
    );
  }

  List<Widget> _rows(List<ExerciseModel> exercises) => [
    for (final exercise in exercises)
      _ExerciseRow(
        key: ValueKey(exercise.id),
        exercise: exercise,
        selected: isSelected?.call(exercise),
        onPressed: () => onExercisePressed(exercise),
      ),
  ];
}

class _ExerciseRow extends StatelessWidget {
  const new({
    required this.exercise,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final ExerciseModel exercise;

  /// Null when the list shows no selection.
  final bool? selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;
    // One node with its own tap, not MergeSemantics: a merged row added
    // while the list was covered broke the semantics tree when the route
    // above it popped (Flutter 3.47, `_buildSemanticsSubtree`).
    return Semantics(
      button: true,
      selected: selected,
      label: exercise.name,
      value: exercise.description,
      onTap: onPressed,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        child: AppListRow(
          title: exercise.name,
          subtitle: exercise.description,
          thumbnail: ExerciseImage(exercise),
          accessory: selected == null
              ? const AppListRowChevron()
              : AppListRowCheckmark(selected: selected),
        ),
      ),
    );
  }
}

/// The filter chips (Swift's filter bar): each opens a menu, and a chip
/// fills and counts itself while it narrows the list.
class _FilterBar extends StatelessWidget {
  const new({required this.library, required this.filters});

  final TrainingLibrary library;
  final ExerciseFilters filters;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ExerciseListCubit>();
    void change(ExerciseFilters filters, String name) =>
        cubit.filtersChanged(filters, name);
    final gym = library.gyms
        .where((gym) => gym.id == filters.gymProfileId)
        .firstOrNull;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: Row(
        spacing: AppSpacing.xs,
        children: [
          // Offered only while something is filtered: a reset that resets
          // nothing reads as broken.
          if (filters.isActive)
            IconButton(
              icon: const Icon(AppSymbols.logAgain),
              tooltip: l10n.filterClear,
              onPressed: cubit.filtersReset,
            ),
          _ChoiceChip<String?>(
            label: gym?.name ?? l10n.filterGym,
            icon: AppSymbols.gym,
            value: filters.gymProfileId,
            options: [
              (null, l10n.filterAnyEquipment),
              for (final gym in library.gyms) (gym.id, gym.name),
            ],
            onChanged: (id) =>
                change(filters.copyWith(gymProfileId: () => id), 'gym'),
          ),
          _MultiChip<ExerciseType>(
            title: l10n.filterType,
            icon: AppSymbols.exercise,
            options: ExerciseType.values,
            name: l10n.exerciseTypeName,
            selection: filters.types,
            onChanged: (types) =>
                change(filters.copyWith(types: types), 'Type'),
          ),
          _MultiChip<Laterality>(
            title: l10n.filterLaterality,
            icon: AppSymbols.splitSides,
            options: Laterality.values,
            name: l10n.lateralityName,
            selection: filters.lateralities,
            onChanged: (lateralities) => change(
              filters.copyWith(lateralities: lateralities),
              'Laterality',
            ),
          ),
          _MultiChip<EquipmentKind>(
            title: l10n.filterResistance,
            icon: AppSymbols.weight,
            options: EquipmentKind.values,
            name: l10n.equipmentKindName,
            selection: filters.resistanceKinds,
            onChanged: (kinds) =>
                change(filters.copyWith(resistanceKinds: kinds), 'Resistance'),
          ),
          _MultiChip<EquipmentKind>(
            title: l10n.filterSupport,
            icon: AppSymbols.equipment,
            options: EquipmentKind.values,
            name: l10n.equipmentKindName,
            selection: filters.supportKinds,
            onChanged: (kinds) =>
                change(filters.copyWith(supportKinds: kinds), 'Support'),
          ),
          _ratingChip(
            l10n,
            l10n.filterRangeOfMotion,
            filters.minimumRangeOfMotion,
            (rating) => change(
              filters.copyWith(minimumRangeOfMotion: () => rating),
              'Range of Motion',
            ),
          ),
          _ratingChip(
            l10n,
            l10n.filterStability,
            filters.minimumStability,
            (rating) => change(
              filters.copyWith(minimumStability: () => rating),
              'Stability',
            ),
          ),
          _ChoiceChip<ExerciseLibraryScope>(
            label: switch (filters.library) {
              ExerciseLibraryScope.all => l10n.filterLibrary,
              ExerciseLibraryScope.mine => l10n.exercisesCustomHeader,
              ExerciseLibraryScope.official => l10n.exercisesOfficialHeader,
            },
            icon: AppSymbols.library,
            value: filters.library,
            isActive: filters.library != ExerciseLibraryScope.all,
            options: [
              (ExerciseLibraryScope.all, l10n.exercisesAllOption),
              (ExerciseLibraryScope.mine, l10n.exercisesCustomHeader),
              (ExerciseLibraryScope.official, l10n.exercisesOfficialHeader),
            ],
            onChanged: (scope) =>
                change(filters.copyWith(library: scope), 'library'),
          ),
        ],
      ),
    );
  }

  /// A floor on a 1–5 rating rather than an exact value.
  Widget _ratingChip(
    AppLocalizations l10n,
    String title,
    int? minimum,
    ValueChanged<int?> onChanged,
  ) => _ChoiceChip<int?>(
    label: minimum == null ? title : l10n.filterRatingChip(title, minimum),
    icon: AppSymbols.filter,
    value: minimum,
    options: [
      (null, l10n.filterAny),
      for (var rating = 1; rating <= 5; rating++)
        (rating, '${AppFormat.number(rating)}+'),
    ],
    onChanged: onChanged,
  );
}

/// A chip whose menu picks one option; filled while [value] isn't the first
/// option, or while [isActive] says so.
class _ChoiceChip<T> extends StatelessWidget {
  const new({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
    this.isActive,
  });

  final String label;
  final IconData icon;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final bool? isActive;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final (option, name) in options)
          MenuItemButton(
            leadingIcon: Icon(
              AppSymbols.selected,
              color: option == value ? null : Colors.transparent,
            ),
            onPressed: () => onChanged(option),
            child: Semantics(selected: option == value, child: Text(name)),
          ),
      ],
      builder: (context, controller, _) => AppChip(
        label: label,
        icon: icon,
        selected: isActive ?? value != options.first.$1,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// A chip whose menu ticks any number of options, staying open between
/// picks.
class _MultiChip<T> extends StatelessWidget {
  const new({
    required this.title,
    required this.icon,
    required this.options,
    required this.name,
    required this.selection,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final List<T> options;
  final String Function(T) name;
  final Set<T> selection;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final option in options)
          CheckboxMenuButton(
            value: selection.contains(option),
            closeOnActivate: false,
            onChanged: (checked) => onChanged(
              (checked ?? false)
                  ? {...selection, option}
                  : ({...selection}..remove(option)),
            ),
            child: Text(name(option)),
          ),
      ],
      builder: (context, controller, _) => AppChip(
        label: selection.isEmpty
            ? title
            : context.l10n.filterCountChip(title, selection.length),
        icon: icon,
        selected: selection.isNotEmpty,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
