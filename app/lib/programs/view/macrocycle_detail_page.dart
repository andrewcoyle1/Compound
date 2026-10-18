import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/macrocycle_draft_cubit.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/programs/view/program_widgets.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:program_repository/program_repository.dart';

/// One macrocycle, new or saved (Swift `MacrocycleDetailView`): its name,
/// its mesocycles in order (drag to reorder, swipe to remove), where to
/// start, and the user's mesocycles to add. Save keeps the edits; Start
/// follows it from the chosen point, asking first when another is
/// followed, and Delete removes it.
class const MacrocycleDetailPage({
  required final String macrocycleId,
  super.key,
}) extends StatelessWidget {
  /// The path under the macrocycles.
  static const path = ':$idParameter';

  /// The route name.
  static const name = 'macrocycleDetail';

  /// The path parameter holding the macrocycle's id.
  static const idParameter = 'macrocycleId';

  /// The id that opens a new macrocycle.
  static const newId = 'new';

  /// Opens the macrocycle [id], or a new one for [newId].
  static Future<void> open(BuildContext context, String id) =>
      context.pushNamed(name, pathParameters: {idParameter: id});

  @override
  Widget build(BuildContext context) {
    final state = context.read<ProgramsCubit>().state;
    final existing = state.macrocycles
        .where((macrocycle) => macrocycle.id == macrocycleId)
        .firstOrNull;
    return BlocProvider(
      create: (_) => MacrocycleDraftCubit(
        mesocycles: state.mesocycles,
        existing: existing,
      ),
      child: _MacrocycleDetailView(existing: existing),
    );
  }
}

class const _MacrocycleDetailView({required final Macrocycle? existing})
    extends StatefulWidget {
  @override
  State<_MacrocycleDetailView> createState() => _MacrocycleDetailViewState();
}

class _MacrocycleDetailViewState extends State<_MacrocycleDetailView> {
  static const _screen = 'MacrocycleDetailView';

  late final ProgramsCubit _programs;

  @override
  void initState() {
    super.initState();
    _programs = context.read<ProgramsCubit>()..appeared(_screen, _parameters);
  }

  late final _name = TextEditingController(
    text: context.read<MacrocycleDraftCubit>().state.name,
  );
  var _saving = false;

  Map<String, Object?> get _parameters => {'is_new': widget.existing == null};

  @override
  void dispose() {
    _programs.disappeared(_screen, _parameters);
    _name.dispose();
    super.dispose();
  }

  /// Being followed now, so starting it again starts over.
  bool get _isFollowing {
    final current = _programs.state.currentMacrocycle;
    return widget.existing != null &&
        current?.id == widget.existing!.id &&
        current?.status == MacrocycleStatus.active;
  }

  Macrocycle _edited(MacrocycleDraft draft) => draft.edited(
    existing: widget.existing,
    authorId: switch (context.read<AppBloc>().state) {
      AppAuthenticated(:final user) => user.uid,
      _ => '',
    },
    newId: newUuid,
    now: DateTime.now(),
  );

  Future<void> _write(Future<void> Function(ProgramsCubit) write) async {
    setState(() => _saving = true);
    final ok = await _programs.succeeded(write);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      unawaited(HapticFeedback.successNotification());
      context.pop();
    } else {
      unawaited(HapticFeedback.errorNotification());
      await showFailureAlert(
        context,
        context.l10n.programSaveFailed,
        context.l10n.programTryAgain,
      );
    }
  }

  Future<void> _start(MacrocycleDraft draft) async {
    final l10n = context.l10n;
    final current = _programs.state.currentMacrocycle;
    if (current != null && current.status == MacrocycleStatus.active) {
      final confirmed = await confirmDestructive(
        context,
        title: _isFollowing
            ? l10n.programRestartNamed(current.name)
            : l10n.programReplaceNamed(current.name),
        message: l10n.programReplaceMessage,
        confirmLabel: _startTitle(l10n),
      );
      if (!confirmed || !mounted) return;
    }
    await _write(
      (c) => c.startMacrocycle(
        _edited(draft),
        mesocycleIndex: draft.startMesocycleIndex,
        microcycleIndex: draft.startMicrocycleIndex,
      ),
    );
  }

  Future<void> _delete(Macrocycle existing) async {
    final l10n = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.programDeleteNamed(existing.name),
      message: l10n.programDeleteMacrocycleMessage,
      confirmLabel: l10n.programDelete,
    );
    if (!confirmed || !mounted) return;
    await _write((c) => c.deleteMacrocycle(existing));
  }

  String _startTitle(AppLocalizations l10n) => _isFollowing
      ? l10n.programRestartMacrocycle
      : l10n.programStartMacrocycle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = context.watch<MacrocycleDraftCubit>().state;
    final cubit = context.read<MacrocycleDraftCubit>();
    final mesocycles = context.select<ProgramsCubit, List<Mesocycle>>(
      (programs) => programs.state.mesocycles,
    );
    cubit.mesocyclesChanged(mesocycles);
    final existing = widget.existing;
    final scheme = Theme.of(context).colorScheme;
    final secondary = AppTextStyles.rowDetail.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final entries = [
      for (final (index, id) in draft.mesocycleIds.indexed)
        if (mesocycles.where((m) => m.id == id).firstOrNull case final m?)
          (index, m),
    ];
    final library = [...mesocycles]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final canSave = draft.canSave && !_saving;
    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? l10n.programNewMacrocycle : draft.name),
        actions: [
          IconButton(
            icon: const Icon(AppSymbols.success),
            tooltip: l10n.usernameSave,
            onPressed: canSave
                ? () =>
                      unawaited(_write((c) => c.saveMacrocycle(_edited(draft))))
                : null,
          ),
          if (existing != null)
            PopupMenuButton<void>(
              icon: Icon(AppSymbols.more),
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () => unawaited(_delete(existing)),
                  child: Text(
                    l10n.programDeleteMacrocycle,
                    style: TextStyle(color: context.appColors.danger),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: LibrarySections(
          children: [
            AppSection(
              header: l10n.onboardingGymName,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.l,
                    vertical: AppSpacing.s,
                  ),
                  child: TextField(
                    controller: _name,
                    onChanged: cubit.nameChanged,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: l10n.programMacrocycleNameHint,
                    ),
                  ),
                ),
              ],
            ),
            AppSection(
              header: l10n.programMesocyclesTitle,
              footer: l10n.programMesocyclesFooter,
              children: [
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Text(
                      l10n.programAddMesocyclesHint,
                      style: secondary,
                    ),
                  )
                else
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    onReorderItem: cubit.moved,
                    children: [
                      for (final (index, mesocycle) in entries)
                        AppSwipeActions(
                          key: ValueKey('$index-${mesocycle.id}'),
                          trailing: [
                            AppSwipeAction(
                              label: l10n.programDelete,
                              icon: AppSymbols.delete,
                              isDestructive: true,
                              onPressed: () => cubit.removed(index),
                            ),
                          ],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: AppSpacing.l,
                                  top: AppSpacing.s,
                                ),
                                child: Text(
                                  l10n.programMesocycleNumber(index + 1),
                                  style: AppTextStyles.label.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              MesocycleHeader(mesocycle: mesocycle),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            if (draft.mesocycleIds.isNotEmpty)
              AppSection(
                header: l10n.programStartAt,
                footer: l10n.programStartAtFooter,
                children: [
                  _Picker(
                    title: l10n.programMesocycle,
                    value: draft.startMesocycleIndex,
                    options: {
                      for (final (index, mesocycle) in entries)
                        index: l10n.programNumberedName(
                          index + 1,
                          mesocycle.name,
                        ),
                    },
                    onChanged: cubit.startMesocycleChanged,
                  ),
                  _Picker(
                    title: l10n.programMicrocycle,
                    value: draft.startMicrocycleIndex,
                    options: {
                      for (
                        var index = 0;
                        index < draft.startMicrocycleCount(mesocycles);
                        index++
                      )
                        index: l10n.programMicrocycleNumber(index + 1),
                    },
                    onChanged: cubit.startMicrocycleChanged,
                  ),
                ],
              ),
            AppSection(
              header: l10n.programYourMesocycles,
              children: [
                if (library.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Text(l10n.programLibraryEmptyHint, style: secondary),
                  ),
                for (final mesocycle in library)
                  Semantics(
                    button: true,
                    hint: l10n.programAddMesocycleHint,
                    child: InkWell(
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        cubit.added(mesocycle);
                        if (_name.text.isEmpty) _name.text = mesocycle.name;
                      },
                      child: MesocycleHeader(
                        mesocycle: mesocycle,
                        trailing: Icon(AppSymbols.add, color: scheme.primary),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomCta(
        children: [
          AppCtaButton(
            label: _startTitle(l10n),
            isLoading: _saving,
            onPressed: canSave ? () => unawaited(_start(draft)) : null,
          ),
        ],
      ),
    );
  }
}

/// A row that picks one of [options] from a menu.
class const _Picker({
  required final String title,
  required final int value,
  required final Map<int, String> options,
  required final ValueChanged<int> onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final MapEntry(:key, :value) in options.entries)
          PopupMenuItem(value: key, child: Text(value)),
      ],
      child: AppListRow(
        title: title,
        accessory: AppListRowValue(options[value] ?? ''),
      ),
    );
  }
}
