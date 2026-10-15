import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/programs/view/macrocycle_detail_page.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:program_repository/program_repository.dart';

/// Every macrocycle the user has (Swift `MacrocyclesView`): the one
/// followed first, then the rest, newest first. Each opens its detail; +
/// makes a new one. Importing a program comes with Programs part 2.
class MacrocyclesPage extends StatefulWidget {
  const new({super.key});

  /// The path under the Training tab.
  static const path = 'macrocycles';

  /// The route name.
  static const name = 'macrocycles';

  static const _screen = 'MacrocyclesView';

  @override
  State<MacrocyclesPage> createState() => _MacrocyclesPageState();
}

class _MacrocyclesPageState extends State<MacrocyclesPage> {
  late final ProgramsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<ProgramsCubit>()..appeared(MacrocyclesPage._screen);
  }

  @override
  void dispose() {
    _cubit.disappeared(MacrocyclesPage._screen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ProgramsCubit>().state;
    final current = state.currentMacrocycle;
    final others = [
      for (final macrocycle in state.macrocycles)
        if (macrocycle.id != current?.id) macrocycle,
    ]..sort((a, b) => b.dateModified.compareTo(a.dateModified));
    void open(String id) => unawaited(MacrocycleDetailPage.open(context, id));
    Widget row(Macrocycle macrocycle) => AppListRowButton(
      title: macrocycle.name,
      subtitle: _subtitle(l10n, macrocycle),
      icon: AppSymbols.macrocycle,
      onPressed: () => open(macrocycle.id),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.programMacrocyclesTitle),
        actions: [
          IconButton(
            icon: const Icon(AppSymbols.add),
            tooltip: l10n.programNewMacrocycle,
            onPressed: () => open(MacrocycleDetailPage.newId),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: current == null && others.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LibraryEmptyState(
                        icon: AppSymbols.macrocycle,
                        title: l10n.programNoMacrocycles,
                        message: l10n.programNoMacrocyclesMessage,
                      ),
                      FilledButton(
                        onPressed: () => open(MacrocycleDetailPage.newId),
                        child: Text(l10n.programNewMacrocycle),
                      ),
                    ],
                  ),
                ),
              )
            : LibrarySections(
                children: [
                  if (current != null)
                    AppSection(
                      header: l10n.programFollowing,
                      children: [row(current)],
                    ),
                  if (others.isNotEmpty)
                    AppSection(
                      header: l10n.programSaved,
                      children: [for (final other in others) row(other)],
                    ),
                ],
              ),
      ),
    );
  }

  /// "3 mesocycles · Mesocycle 2 of 3".
  static String _subtitle(AppLocalizations l10n, Macrocycle macrocycle) {
    final count = macrocycle.mesocycleIds.length;
    final status = switch (macrocycle.status) {
      MacrocycleStatus.active => l10n.programMesocycleOf(
        macrocycle.mesocycleIndex + 1,
        count,
      ),
      MacrocycleStatus.completed => l10n.programComplete,
      MacrocycleStatus.notStarted => l10n.programNotStarted,
      MacrocycleStatus.ended => l10n.programEnded,
    };
    return '${l10n.programMesocycleCount(count)} · $status';
  }
}
