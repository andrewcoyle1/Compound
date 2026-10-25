import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/cubit/mesocycle_design_cubit.dart';
import 'package:compound/programs/view/mesocycle_style.dart';
import 'package:compound/programs/view/program_widgets.dart';
import 'package:compound/science/method_info.dart';
import 'package:compound/science/view/method_info_button.dart';
import 'package:compound/workout_editor/view/editor_widgets.dart'
    show CountStepper;
import 'package:compound_models/compound_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A page of the mesocycle editor (Swift `MesocycleSettingsView`): its
/// name, cycle count, colour and icon, day order, deload and
/// periodisation, each edited in place on the editor's own state, and
/// Activate, which saves it, follows it and comes back to the days.
class MesocycleSettingsPage extends StatefulWidget {
  const new({super.key});

  @override
  State<MesocycleSettingsPage> createState() => _MesocycleSettingsPageState();
}

class _MesocycleSettingsPageState extends State<MesocycleSettingsPage> {
  static const _screen = 'ProgramSettingsView';

  late final MesocycleDesignCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<MesocycleDesignCubit>()..appeared(_screen);
  }

  @override
  void dispose() {
    _cubit.disappeared(_screen);
    super.dispose();
  }

  /// Runs [sheet] between its screen's appear and disappear events.
  Future<T?> _tracked<T>(String screen, Future<T?> Function() sheet) async {
    _cubit.appeared(screen);
    try {
      return await sheet();
    } finally {
      _cubit.disappeared(screen);
    }
  }

  Future<void> _done(MesocycleDesignState state) async {
    if (state.status == MesocycleDesignStatus.succeeded) {
      unawaited(AppHaptics.success());
      if (mounted) Navigator.of(context).pop();
      return;
    }
    unawaited(AppHaptics.error());
    if (!mounted) return;
    await showFailureAlert(
      context,
      context.l10n.programActivateFailed,
      context.l10n.programTryAgain,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<MesocycleDesignCubit>().state;
    final mesocycle = state.mesocycle;
    return BlocListener<MesocycleDesignCubit, MesocycleDesignState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.lastAction == MesocycleDesignAction.activate &&
          (current.status == MesocycleDesignStatus.succeeded ||
              current.status == MesocycleDesignStatus.failed),
      listener: (_, state) => unawaited(_done(state)),
      child: AppScaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.programMesocycleSettings),
              Text(
                mesocycle.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.rowDetail.secondary(context),
              ),
            ],
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              AppSection(
                children: [
                  AppListRowButton(
                    title: l10n.programName,
                    subtitle: mesocycle.name,
                    icon: AppSymbols.mesocycle,
                    onPressed: () async {
                      final name = await _tracked(
                        'RenameWorkoutTemplateModelView',
                        () => showRenameSheet(
                          context,
                          title: l10n.programName,
                          initialName: mesocycle.name,
                        ),
                      );
                      if (name != null) _cubit.edit(name: name);
                    },
                  ),
                  _CycleStepper(
                    cycles: mesocycle.numMicrocycles,
                    onChanged: (cycles) => _cubit.edit(numMicrocycles: cycles),
                  ),
                  AppListRowButton(
                    // The row's own glyph shows both.
                    title: l10n.programColourAndIcon,
                    icon: mesocycleGlyph(mesocycle.icon),
                    tint: AppColors.fromHex(mesocycle.colour),
                    onPressed: () async {
                      final chosen = await _tracked(
                        'EditMesocycleColourIconView',
                        () => showColourIconSheet(
                          context,
                          colour: mesocycle.colour,
                          icon: mesocycle.icon,
                        ),
                      );
                      if (chosen case (final colour, final icon)) {
                        _cubit.edit(colour: colour, icon: icon);
                      }
                    },
                  ),
                  AppListRowButton(
                    title: l10n.programDayOrder,
                    subtitle: [
                      for (final day in mesocycle.workoutTemplates) day.name,
                    ].join(', '),
                    icon: AppSymbols.calendar,
                    onPressed: () async {
                      final days = await _tracked(
                        'EditDayOrderView',
                        () => showDayOrderSheet(
                          context,
                          mesocycle.workoutTemplates,
                        ),
                      );
                      if (days != null) _cubit.edit(days: days);
                    },
                  ),
                  AppListRowButton(
                    title: l10n.programDeload,
                    subtitle: deloadTitle(l10n, mesocycle.deload),
                    icon: AppSymbols.rest,
                    onPressed: () async {
                      final deload = await _tracked(
                        'EditDeloadView',
                        () => showDeloadSheet(context, mesocycle.deload),
                      );
                      if (deload != null) _cubit.edit(deload: deload);
                    },
                  ),
                  AppListRowToggle(
                    title: l10n.programPeriodization,
                    subtitle: l10n.programPeriodizationSubtitle,
                    icon: AppSymbols.strategy,
                    value: mesocycle.periodisation,
                    onChanged: (on) => _cubit.edit(periodisation: on),
                  ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomCta(
          children: [
            AppCtaButton(
              label: l10n.programActivateMesocycle,
              isLoading: state.status == MesocycleDesignStatus.saving,
              onPressed: state.canSave
                  ? () => unawaited(_cubit.activate(screen: _screen))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Number of Cycles", 1 to 16 (Swift's `Stepper`).
class const _CycleStepper({
  required final int cycles,
  required final ValueChanged<int> onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CountStepper(
      title: l10n.programNumberOfCycles,
      subtitle: l10n.programCycleCount(cycles),
      icon: AppSymbols.repeatMacrocycle,
      value: cycles,
      min: 1,
      max: 16,
      decreaseLabel: l10n.programFewerCycles,
      increaseLabel: l10n.programMoreCycles,
      onChanged: onChanged,
    );
  }
}

/// A sheet with Close, its [title] and Save (Swift's close and confirm
/// toolbar buttons) over [child]. Save is off while [canSave] is false.
class const _EditorSheet({
  required final String title,
  required final bool canSave,
  required final VoidCallback onSave,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return AppScaffold(
      appBar: AppBar(
        leading: AppToolbarButton.close(
          semanticLabel: localizations.closeButtonTooltip,
        ),
        title: Text(title),
        actions: [
          AppToolbarButton.confirm(
            semanticLabel: localizations.saveButtonLabel,
            onPressed: canSave ? onSave : null,
          ),
        ],
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}

Future<T?> _sheet<T>(BuildContext context, Widget child) =>
    showAppSheet<T>(context: context, builder: (_) => child);

/// Asks for a name, starting from [initialName]; the trimmed name, or null
/// when closed (Swift `RenameWorkoutTemplateModelView`). A blank name
/// cannot be saved.
Future<String?> showRenameSheet(
  BuildContext context, {
  required String title,
  required String initialName,
}) => _sheet(context, _RenameSheet(title: title, initialName: initialName));

class const _RenameSheet({
  required final String title,
  required final String initialName,
}) extends StatefulWidget {
  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final _name = TextEditingController(text: widget.initialName);

  String get _trimmed => _name.text.trim();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_trimmed.isNotEmpty) Navigator.of(context).pop(_trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return _EditorSheet(
      title: widget.title,
      canSave: _trimmed.isNotEmpty,
      onSave: _save,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppTextField(
            hint: context.l10n.programDayNameHint,
            controller: _name,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
    );
  }
}

/// Picks a colour and icon, starting from the mesocycle's (Swift
/// `EditMesocycleColourIconView`); null when closed.
Future<(String, String)?> showColourIconSheet(
  BuildContext context, {
  required String colour,
  required String icon,
}) => _sheet(context, _ColourIconSheet(colour: colour, icon: icon));

class const _ColourIconSheet({
  required final String colour,
  required final String icon,
}) extends StatefulWidget {
  @override
  State<_ColourIconSheet> createState() => _ColourIconSheetState();
}

class _ColourIconSheetState extends State<_ColourIconSheet> {
  late String _colour = widget.colour;
  late String _icon = widget.icon;

  @override
  Widget build(BuildContext context) {
    return _EditorSheet(
      title: context.l10n.programColourAndIcon,
      canSave: true,
      onSave: () => Navigator.of(context).pop((_colour, _icon)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
        child: MesocycleColourIconGrid(
          colour: _colour,
          icon: _icon,
          onColourPressed: (colour) => setState(() => _colour = colour),
          onIconPressed: (icon) => setState(() => _icon = icon),
        ),
      ),
    );
  }
}

/// Reorders [days] by dragging (Swift `EditDayOrderView`); the new order,
/// or null when closed.
Future<List<WorkoutTemplateModel>?> showDayOrderSheet(
  BuildContext context,
  List<WorkoutTemplateModel> days,
) => _sheet(context, _DayOrderSheet(days: days));

class const _DayOrderSheet({required final List<WorkoutTemplateModel> days})
    extends StatefulWidget {
  @override
  State<_DayOrderSheet> createState() => _DayOrderSheetState();
}

class _DayOrderSheetState extends State<_DayOrderSheet> {
  late List<WorkoutTemplateModel> _days = widget.days;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return _EditorSheet(
      title: l10n.programDayOrder,
      canSave: true,
      onSave: () => Navigator.of(context).pop(_days),
      child: ReorderableListView(
        onReorderItem: (from, to) => setState(
          () => _days = List.of(_days)
            ..removeAt(from)
            ..insert(to, _days[from]),
        ),
        children: [
          for (final day in _days)
            AppListRow(
              key: ValueKey(day.workoutId),
              title: day.name,
              subtitle: day.exercises.isEmpty
                  ? l10n.programRest
                  : l10n.programWorkout,
              icon: day.exercises.isEmpty
                  ? AppSymbols.restDay
                  : AppSymbols.workout,
              tint: secondary,
            ),
        ],
      ),
    );
  }
}

/// Picks where the deload falls (Swift `EditDeloadView`); null when
/// closed.
Future<DeloadType?> showDeloadSheet(
  BuildContext context,
  DeloadType selected,
) => _sheet(context, _DeloadSheet(selected: selected));

class const _DeloadSheet({required final DeloadType selected})
    extends StatefulWidget {
  @override
  State<_DeloadSheet> createState() => _DeloadSheetState();
}

class _DeloadSheetState extends State<_DeloadSheet> {
  late DeloadType _selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _EditorSheet(
      title: l10n.programDeload,
      canSave: true,
      onSave: () => Navigator.of(context).pop(_selected),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            header: l10n.programDeloadWeek,
            trailing: MethodInfoButton(MethodInfo.mesocycleDeload(l10n)),
            footer: l10n.programDeloadFooter,
            children: [
              for (final type in DeloadType.values)
                AppSelectableRow(
                  title: deloadTitle(l10n, type),
                  subtitle: switch (type) {
                    DeloadType.none => l10n.programDeloadNoneDescription,
                    DeloadType.start => l10n.programDeloadFirstDescription,
                    DeloadType.end => l10n.programDeloadLastDescription,
                  },
                  selected: type == _selected,
                  onPressed: () => setState(() => _selected = type),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
