import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/create_exercise/cubit/equipment_picker_cubit.dart';
import 'package:compound/create_exercise/cubit/exercise_equipment_cubit.dart';
import 'package:compound/create_exercise/logic/exercise_draft.dart';
import 'package:compound/create_exercise/view/create_exercise_page.dart';
import 'package:compound/create_exercise/view/final_exercise_details_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/training_library/bloc/training_library_bloc.dart';
import 'package:compound/training_library/logic/exercise_filters.dart';
import 'package:compound/training_library/logic/search_match.dart';
import 'package:compound/training_library/view/library_names.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound_models/compound_models.dart' show EquipmentKind;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The equipment the new exercise is done with, as one or more variations
/// (Swift `ExerciseEquipmentView`).
class ExerciseEquipmentPage extends StatelessWidget {
  const new({required this.draft, super.key});

  final ExerciseDraft draft;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExerciseEquipmentCubit(
        draft: draft,
        analytics: context.read<AnalyticsRepository>(),
      ),
      child: const ExerciseEquipmentView(),
    );
  }
}

class ExerciseEquipmentView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ExerciseEquipmentCubit>();
    final state = context.watch<ExerciseEquipmentCubit>().state;
    final types = _equipmentTypes(context);
    String names(List<EquipmentKey> keys) =>
        [for (final key in keys) types[key] ?? l10n.removedEquipment]
            .join(', ');
    // Whether the equipment is required joins the subtitle.
    String detail(String subtitle, String? note) =>
        note == null ? subtitle : '$subtitle · $note';
    return ScreenAnalytics(
      appeared: cubit.appeared,
      disappeared: cubit.disappeared,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.createExerciseSelectEquipment)),
        body: SafeArea(
          bottom: false,
          child: LibrarySections(
            children: [
              AppSection(
                children: [
                  AppListRowToggle(
                    key: const Key('ExerciseEquipment.bodyweight'),
                    title: l10n.createExerciseBodyweight,
                    subtitle: l10n.createExerciseBodyweightMessage,
                    value: state.isBodyweight,
                    onChanged: (value) =>
                        cubit.bodyweightChanged(isBodyweight: value),
                  ),
                ],
              ),
              // Bodyweight work keeps its equipment too: the bar a pull-up
              // hangs from, the machine that assists it.
              for (final (index, variation) in state.variations.indexed)
                AppSection(
                  header: l10n.exerciseVariationHeader(index + 1),
                  children: [
                    AppListRowButton(
                      key: Key('ExerciseEquipment.resistance.$index'),
                      title: l10n.filterResistance,
                      subtitle: variation.resistance.isEmpty
                          ? detail(
                              l10n.createExerciseResistancePrompt,
                              state.isBodyweight
                                  ? l10n.editorOptional
                                  : l10n.createExerciseRequired,
                            )
                          : names(variation.resistance),
                      onPressed: () => unawaited(
                        _pick(
                          context,
                          title: l10n.createExerciseResistanceEquipment,
                          support: false,
                          chosen: variation.resistance,
                          write: (keys) =>
                              cubit.resistanceChanged(variation.id, keys),
                        ),
                      ),
                    ),
                    AppListRowButton(
                      key: Key('ExerciseEquipment.support.$index'),
                      title: l10n.filterSupport,
                      subtitle: variation.support.isEmpty
                          ? detail(
                              l10n.createExerciseSupportPrompt,
                              l10n.editorOptional,
                            )
                          : names(variation.support),
                      onPressed: () => unawaited(
                        _pick(
                          context,
                          title: l10n.createExerciseSupportEquipment,
                          support: true,
                          chosen: variation.support,
                          write: (keys) =>
                              cubit.supportChanged(variation.id, keys),
                        ),
                      ),
                    ),
                    if (state.variations.length > 1)
                      AppListRowButton(
                        key: Key('ExerciseEquipment.delete.$index'),
                        title: l10n.createExerciseDeleteVariation,
                        icon: AppSymbols.delete,
                        tint: context.appColors.danger,
                        onPressed: () => cubit.variationDeleted(variation.id),
                      ),
                  ],
                ),
              AppSection(
                children: [
                  AppListRowButton(
                    key: const Key('ExerciseEquipment.addVariation'),
                    title: l10n.createExerciseAddVariation,
                    icon: AppSymbols.add,
                    onPressed: cubit.variationAdded,
                  ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomCta(
          children: [
            AppCtaButton(
              key: const Key('ExerciseEquipment.next'),
              label: l10n.createExerciseNext,
              onPressed: state.canContinue
                  ? () => unawaited(
                      pushCreateStep(
                        context,
                        FinalExerciseDetailsPage(draft: cubit.next),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the picker on one half of the catalogue, writing each change
  /// straight into the tapped variation.
  static Future<void> _pick(
    BuildContext context, {
    required String title,
    required bool support,
    required List<EquipmentKey> chosen,
    required ValueChanged<List<EquipmentKey>> write,
  }) {
    final types = _equipmentTypes(context);
    final analytics = context.read<AnalyticsRepository>();
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => BlocProvider(
          create: (_) =>
              EquipmentPickerCubit(chosen: chosen, analytics: analytics),
          child: BlocListener<EquipmentPickerCubit, List<EquipmentKey>>(
            listener: (_, keys) => write(keys),
            child: EquipmentPickerView(
              title: title,
              items: {
                for (final MapEntry(:key, :value) in types.entries)
                  if (ExerciseDefinitionRules.isSupport(key.$1) == support)
                    key: value,
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Every equipment type by key, with its name.
  static Map<EquipmentKey, String> _equipmentTypes(BuildContext context) =>
      switch (context.read<TrainingLibraryBloc>().state) {
        TrainingLibraryLoaded(:final library) => {
          for (final (key, name) in library.equipmentTypes) key: name,
        },
        _ => const {},
      };
}

/// Ticking equipment for one row of the equipment step (Swift
/// `EquipmentPickerView`): grouped by kind, filtered by name.
class EquipmentPickerView extends StatefulWidget {
  const new({required this.title, required this.items, super.key});

  final String title;

  /// What can be ticked, with its name.
  final Map<EquipmentKey, String> items;

  @override
  State<EquipmentPickerView> createState() => _EquipmentPickerViewState();
}

class _EquipmentPickerViewState extends State<EquipmentPickerView> {
  late final EquipmentPickerCubit _cubit;
  var _query = '';

  @override
  void initState() {
    super.initState();
    _cubit = context.read<EquipmentPickerCubit>()..appeared();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chosen = context.watch<EquipmentPickerCubit>().state;
    final sections = <EquipmentKind, List<(EquipmentKey, String)>>{};
    for (final MapEntry(:key, :value) in widget.items.entries) {
      if (!SearchMatch.isSearching(_query) ||
          SearchMatch.matches(_query, [value])) {
        (sections[key.$1] ??= []).add((key, value));
      }
    }
    final kinds = sections.keys.toList()
      ..sort(
        (a, b) => l10n
            .equipmentKindName(a)
            .toLowerCase()
            .compareTo(l10n.equipmentKindName(b).toLowerCase()),
      );
    return Scaffold(
      appBar: AppBar(leading: const CloseButton(), title: Text(widget.title)),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                0,
              ),
              child: LibrarySearchField(
                hint: l10n.createExerciseFilterEquipment,
                onChanged: (query) => setState(() => _query = query),
              ),
            ),
            Expanded(
              child: kinds.isEmpty
                  ? LibraryEmptyState(
                      icon: AppSymbols.search,
                      title: l10n.searchNoResults(_query.trim()),
                      message: l10n.searchNoResultsMessage,
                    )
                  : LibrarySections(
                      children: [
                        for (final kind in kinds)
                          AppSection(
                            header: l10n.equipmentKindName(kind),
                            children: [
                              for (final (key, name)
                                  in sections[kind]!..sort(
                                    (a, b) => a.$2.toLowerCase().compareTo(
                                      b.$2.toLowerCase(),
                                    ),
                                  ))
                                AppSelectableRow(
                                  key: Key('EquipmentPicker.${key.$2}'),
                                  title: name,
                                  selected: chosen.contains(key),
                                  onPressed: () {
                                    unawaited(HapticFeedback.selectionClick());
                                    _cubit.toggled(key);
                                  },
                                ),
                            ],
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
