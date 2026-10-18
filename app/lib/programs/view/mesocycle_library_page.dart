import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/programs_cubit.dart';
import 'package:compound/programs/view/create_mesocycle_pages.dart';
import 'package:compound/programs/view/import_program_page.dart';
import 'package:compound/programs/view/mesocycle_design_page.dart';
import 'package:compound/programs/view/prebuilt_mesocycle_detail_page.dart';
import 'package:compound/programs/view/program_widgets.dart';
import 'package:compound/sharing/view/share_to_follower_page.dart';
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:compound_models/compound_models.dart'
    show MesocycleSharePayload;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show PrebuiltCatalogue;

/// The user's mesocycles and the shipped templates (Swift
/// `MesocycleLibraryView`): the active one, the saved ones (each opening
/// to its days, with Delete in its menu) and the templates, each opening
/// its detail to start. + creates a mesocycle or imports a program.
class MesocycleLibraryPage extends StatefulWidget {
  const new({super.key});

  /// The path under the Training tab.
  static const path = 'mesocycles';

  /// The route name.
  static const name = 'mesocycleLibrary';

  static const _screen = 'TrainingProgramLibraryView';

  @override
  State<MesocycleLibraryPage> createState() => _MesocycleLibraryPageState();
}

class _MesocycleLibraryPageState extends State<MesocycleLibraryPage> {
  late final ProgramsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<ProgramsCubit>()
      ..appeared(MesocycleLibraryPage._screen);
  }

  @override
  void dispose() {
    _cubit.disappeared(MesocycleLibraryPage._screen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<ProgramsCubit>().state;
    final active = state.activeMesocycle;
    final inactive = state.inactiveMesocycles;
    final templates = PrebuiltCatalogue.instance.mesocycles;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.programMesocyclesTitle),
        actions: [
          PopupMenuButton<VoidCallback>(
            icon: const Icon(AppSymbols.add),
            tooltip: l10n.programAddMesocycle,
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: () => unawaited(NameMesocyclePage.open(context)),
                child: Text(l10n.programCreateMesocycle),
              ),
              PopupMenuItem(
                value: () => unawaited(ImportProgramPage.open(context)),
                child: Text(l10n.programImportProgramEllipsis),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: LibrarySections(
          children: [
            if (active != null)
              AppSection(
                header: l10n.programActiveMesocycle,
                children: [_Disclosure(mesocycle: active, onDelete: null)],
              ),
            if (inactive.isNotEmpty)
              AppSection(
                header: l10n.programSavedMesocycles,
                footer: l10n.programSavedMesocyclesFooter,
                children: [
                  for (final mesocycle in inactive)
                    _Disclosure(
                      mesocycle: mesocycle,
                      onDelete: () => unawaited(_delete(context, mesocycle)),
                    ),
                ],
              ),
            if (state.mesocycles.isEmpty && active == null)
              Column(
                children: [
                  LibraryEmptyState(
                    icon: AppSymbols.mesocycle,
                    title: l10n.programNoMesocycles,
                    message: l10n.programNoMesocyclesMessage,
                  ),
                  FilledButton(
                    onPressed: () => unawaited(NameMesocyclePage.open(context)),
                    child: Text(l10n.programCreateMesocycle),
                  ),
                ],
              ),
            if (templates.isNotEmpty)
              AppSection(
                header: l10n.programTemplates,
                footer: l10n.programTemplatesFooter,
                children: [
                  for (final template in templates)
                    Semantics(
                      button: true,
                      child: InkWell(
                        onTap: () => unawaited(
                          context.pushNamed(
                            PrebuiltMesocycleDetailPage.name,
                            pathParameters: {
                              PrebuiltMesocycleDetailPage.idParameter:
                                  template.id,
                            },
                          ),
                        ),
                        child: MesocycleHeader(
                          mesocycle: template,
                          trailing: Icon(
                            AppSymbols.disclosure,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Mesocycle mesocycle) async {
    final l10n = context.l10n;
    final cubit = context.read<ProgramsCubit>();
    final isActive = mesocycle.id == cubit.state.activeMesocycleId;
    final confirmed = await confirmDestructive(
      context,
      title: l10n.programDeleteMesocycle,
      message: isActive
          ? l10n.programDeleteActiveNamedMessage(mesocycle.name)
          : l10n.programDeleteNamedMessage(mesocycle.name),
      confirmLabel: l10n.programDelete,
    );
    if (!confirmed) return;
    final ok = await cubit.succeeded(
      (c) => c.deleteMesocycle(
        mesocycle,
        eventPrefix: MesocycleLibraryPage._screen,
      ),
    );
    if (!ok && context.mounted) {
      await showFailureAlert(
        context,
        l10n.programDeleteFailed,
        l10n.programTryAgain,
      );
    }
  }
}

/// A mesocycle that opens to its days (Swift `MesocycleDisclosureGroup`),
/// with Edit, and Delete when [onDelete] is given, in its menu. The days
/// open nothing, so they carry no chevron.
class const _Disclosure({
  required final Mesocycle mesocycle,
  required final VoidCallback? onDelete,
}) extends StatefulWidget {
  @override
  State<_Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<_Disclosure> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final onDelete = widget.onDelete;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Swift's swipe to delete a saved mesocycle (`InactiveMesocycleView`).
        AppSwipeActions(
          trailing: [
            if (onDelete != null)
              AppSwipeAction(
                label: l10n.programDelete,
                icon: AppSymbols.delete,
                isDestructive: true,
                onPressed: onDelete,
              ),
          ],
          child: Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: MesocycleHeader(
                mesocycle: widget.mesocycle,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<void>(
                      icon: Icon(AppSymbols.more),
                      tooltip: l10n.programMesocycleOptions,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          onTap: () => unawaited(
                            MesocycleDesignPage.edit(
                              context,
                              widget.mesocycle.id,
                            ),
                          ),
                          child: Text(l10n.programEditMesocycle),
                        ),
                        PopupMenuItem(
                          onTap: () => unawaited(
                            showShareToFollower(
                              context,
                              MesocycleSharePayload(widget.mesocycle),
                            ),
                          ),
                          child: Text(l10n.shareWithFriends),
                        ),
                        if (onDelete != null)
                          PopupMenuItem(
                            onTap: onDelete,
                            child: Text(
                              l10n.programDeleteMesocycle,
                              style: TextStyle(color: context.appColors.danger),
                            ),
                          ),
                      ],
                    ),
                    ExcludeSemantics(
                      child: AnimatedRotation(
                        turns: _expanded ? 0.25 : 0,
                        duration: AppMotion.quick.durationOf(context),
                        child: Icon(
                          AppSymbols.disclosure,
                          color: scheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          for (final day in widget.mesocycle.workoutTemplates)
            DayPlanRow(plan: day),
      ],
    );
  }
}
