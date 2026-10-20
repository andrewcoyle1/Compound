import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/gym_profiles/cubit/gym_profile_editor_cubit.dart';
import 'package:compound/gym_profiles/view/gym_text.dart';
import 'package:compound/gym_profiles/view/gym_widgets.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/workout_history/view/workout_text.dart';
import 'package:compound_models/compound_models.dart' show newDocumentId;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// The stacks of one cable or pin-loaded machine, a unit at a time (Swift
/// `EditStackMachineView`, one screen for both kinds). The user's own
/// machines and duplicates can be renamed here.
class StackMachineEditorPage extends StatefulWidget {
  const new({required this.list, required this.machineId, super.key});

  final GymEquipmentList list;
  final String machineId;

  @override
  State<StackMachineEditorPage> createState() => _StackMachineEditorState();
}

class _StackMachineEditorState extends State<StackMachineEditorPage>
    with ScreenAnalytics {
  @override
  String get screen => 'EditStackMachineView';

  late final GymProfileEditorCubit _cubit = context
      .read<GymProfileEditorCubit>();
  late final StackMachine _opening = _machine(_cubit.state.gym)!;
  late ExerciseWeightUnit _unit = GymEditorRules.openingUnit(
    widget.list,
    _opening,
  );

  StackMachine? _machine(GymProfileModel gym) =>
      GymEditorRules.item(gym, widget.list, widget.machineId) as StackMachine?;

  @override
  void dispose() {
    // A machine left without a name keeps the one it had.
    if (_machine(_cubit.state.gym)?.name.trim().isEmpty ?? false) {
      _cubit.edit(
        (gym) => GymEditorRules.restoringBlankName(
          gym,
          widget.list,
          widget.machineId,
          _opening.name,
        ),
      );
    }
    super.dispose();
  }

  void _setStack(WeightStack stack) => _cubit.edit(
    (gym) => GymEditorRules.updatingEntry(
      gym,
      widget.list,
      widget.machineId,
      stack.id,
      (_) => stack.toFirestore(),
    ),
  );

  Future<void> _add(StackMachine machine) async {
    final stack = await showGymSheet<WeightStack>(
      context,
      AddWeightStackSheet(
        machineName: machine.name,
        stacks: machine.ranges,
        unit: _unit,
      ),
    );
    if (stack == null) return;
    _cubit.edit(
      (gym) => GymEditorRules.addingEntry(
        gym,
        widget.list,
        widget.machineId,
        stack.toFirestore(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final machine = _machine(watchGym(context));
    if (machine == null) return AppScaffold(appBar: AppBar());
    final stacks = GymEditorRules.stacks(machine, _unit);
    return AppScaffold(
      appBar: AppBar(
        title: Text(machine.name),
        actions: [
          AppToolbarButton(
            icon: AppSymbols.add,
            semanticLabel: l10n.gymAddRange,
            onPressed: () => unawaited(_add(machine)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            if (GymEditorRules.isCustom(widget.list, machine))
              MachineNameField(list: widget.list, machine: machine),
            GymListHeader(
              title: l10n.gymWeights,
              trailing: WeightUnitSwitch(
                unit: _unit,
                onChanged: (unit) => setState(() => _unit = unit),
              ),
            ),
            if (stacks.isEmpty)
              NoWeights(unit: _unit)
            else
              AppSection(
                children: [
                  for (final stack in stacks)
                    DeletableRow(
                      id: stack.id,
                      onDelete: () => _cubit.edit(
                        (gym) => GymEditorRules.deletingEntries(
                          gym,
                          widget.list,
                          widget.machineId,
                          {stack.id},
                        ),
                      ),
                      child: _StackRow(
                        stack: stack,
                        onEditRange: () => unawaited(
                          showGymSheet<void>(
                            context,
                            EditWeightRangeSheet(
                              machineName: machine.name,
                              stack: stack,
                              onChanged: _setStack,
                            ),
                          ),
                        ),
                        onActiveChanged: (isActive) => _setStack(
                          GymEditorRules.editedStack(
                            stack,
                            (data) => {
                              ...data,
                              GymEquipmentKeys.isActive: isActive,
                            },
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
}

class _StackRow extends StatelessWidget {
  const new({
    required this.stack,
    required this.onEditRange,
    required this.onActiveChanged,
  });

  final WeightStack stack;
  final VoidCallback onEditRange;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.s,
      ),
      child: Row(
        spacing: AppSpacing.m,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Text(stack.name, style: AppTextStyles.rowTitle),
                Text(
                  GymText.stack(l10n, stack),
                  style: AppTextStyles.rowDetail.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                AppTextButton(
                  label: l10n.gymEditRange,
                  onPressed: onEditRange,
                  inline: true,
                ),
              ],
            ),
          ),
          Semantics(
            label: '${stack.name}, ${l10n.gymAvailable}',
            child: Switch.adaptive(
              value: stack.isActive,
              onChanged: onActiveChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// A custom machine's name, which a duplicate or the user's own machine
/// alone can change.
class MachineNameField extends StatefulWidget {
  const new({required this.list, required this.machine, super.key});

  final GymEquipmentList list;
  final GymEquipmentItem machine;

  @override
  State<MachineNameField> createState() => _MachineNameFieldState();
}

class _MachineNameFieldState extends State<MachineNameField> {
  late final _controller = TextEditingController(
    text: GymEditorRules.nameOf(widget.machine),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<GymProfileEditorCubit>();
    return AppSection(
      header: l10n.gymName,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: l10n.gymName,
              border: InputBorder.none,
              filled: false,
            ),
            onChanged: (name) => cubit.edit(
              (gym) => GymEditorRules.updatingItem(
                gym,
                widget.list,
                widget.machine.id,
                (data) => {...data, GymEquipmentKeys.name: name},
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The lightest pin, the heaviest and the step between: an even stack's
/// three numbers, shared by Add Range and Edit Range (Swift
/// `WeightStackGridFields`). A cleared field reads as 0.
class _GridFields extends StatelessWidget {
  const new({required this.stack, required this.onChanged});

  final WeightStack stack;
  final ValueChanged<WeightStack> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unit = WorkoutText.weightUnit(stack.unit).symbol;
    Widget field(String label, String key, double value) => AppNumberField(
      value: value,
      prompt: '0',
      label: label,
      unit: unit,
      onChanged: (typed) => onChanged(
        GymEditorRules.editedStack(stack, (data) {
          return {...data, key: typed ?? 0};
        }),
      ),
    );
    return Column(
      children: [
        field(l10n.gymLightestPin, GymEquipmentKeys.minWeight, stack.minWeight),
        field(l10n.gymHeaviestPin, GymEquipmentKeys.maxWeight, stack.maxWeight),
        field(l10n.gymIncrement, GymEquipmentKeys.increment, stack.increment),
      ],
    );
  }
}

/// Adding a stack to a machine (Swift `AddWeightStackView`), in the unit
/// its editor was showing. Pops with the stack, or nothing when closed.
class AddWeightStackSheet extends StatefulWidget {
  const new({
    required this.machineName,
    required this.stacks,
    required this.unit,
    super.key,
  });

  final String machineName;
  final List<WeightStack> stacks;
  final ExerciseWeightUnit unit;

  @override
  State<AddWeightStackSheet> createState() => _AddWeightStackSheetState();
}

class _AddWeightStackSheetState extends State<AddWeightStackSheet>
    with ScreenAnalytics {
  @override
  String get screen => 'AddWeightStackView';

  late WeightStack _stack = GymEditorRules.newStack(
    id: newDocumentId(),
    unit: widget.unit,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final problem = GymEditorRules.addStackProblem(widget.stacks, _stack);
    return GymSheet(
      title: l10n.gymAddRange,
      subtitle: widget.machineName,
      confirms: true,
      onConfirm: problem == null
          ? () {
              gymSaved();
              Navigator.of(context).pop(_stack);
            }
          : null,
      children: [
        TextField(
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.gymLabel),
          onChanged: (name) => setState(
            () => _stack = GymEditorRules.editedStack(
              _stack,
              (data) => {...data, GymEquipmentKeys.name: name},
            ),
          ),
        ),
        _GridFields(
          stack: _stack,
          onChanged: (stack) => setState(() => _stack = stack),
        ),
        if (problem != null)
          GymFormMessage(GymText.addStackProblem(l10n, problem)),
      ],
    );
  }
}

/// One stack's pins, an even grid or an uneven list, and the add-ons on
/// top (Swift `EditWeightRangeView`). Every change reaches the machine as
/// it is made; leaving puts an unusable stack right
/// ([GymEditorRules.repaired]).
class EditWeightRangeSheet extends StatefulWidget {
  const new({
    required this.machineName,
    required this.stack,
    required this.onChanged,
    super.key,
  });

  final String machineName;
  final WeightStack stack;
  final ValueChanged<WeightStack> onChanged;

  @override
  State<EditWeightRangeSheet> createState() => _EditWeightRangeSheetState();
}

class _EditWeightRangeSheetState extends State<EditWeightRangeSheet>
    with ScreenAnalytics {
  @override
  String get screen => 'EditWeightRangeView';

  late WeightStack _stack = widget.stack;
  double? _addOn;
  double? _pinWeight;
  // Bumped to empty the add fields after an add.
  var _added = 0;

  void _set(WeightStack stack) {
    setState(() => _stack = stack);
    widget.onChanged(stack);
  }

  @override
  void dispose() {
    if (GymEditorRules.needsRepair(_stack)) {
      widget.onChanged(GymEditorRules.repaired(_stack, widget.stack.increment));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unit = WorkoutText.weightUnit(_stack.unit).symbol;
    final weights = _stack.weights;
    final addOn = _addOn;
    final pinWeight = _pinWeight;
    final addOnProblem = addOn == null
        ? null
        : GymEditorRules.addOnProblem(_stack, addOn);
    final pinProblem = pinWeight == null
        ? null
        : GymEditorRules.pinWeightProblem(_stack, pinWeight);
    return GymSheet(
      title: l10n.gymEditRange,
      subtitle: widget.machineName,
      children: [
        if (weights == null) _GridFields(stack: _stack, onChanged: _set),
        AppSection(
          footer: l10n.gymUnevenFooter,
          children: [
            AppListRowToggle(
              title: l10n.gymUnevenStack,
              value: weights != null,
              onChanged: (isUneven) => _set(
                GymEditorRules.settingUneven(_stack, isUneven: isUneven),
              ),
            ),
            if (weights != null) ...[
              for (final (index, weight) in weights.indexed)
                DeletableRow(
                  id: 'pin-$index-$weight',
                  onDelete: () =>
                      _set(GymEditorRules.removingPinWeights(_stack, {index})),
                  child: AppListRow(title: GymText.weight(weight, _stack.unit)),
                ),
              _AddField(
                key: ValueKey('pin-$_added'),
                prompt: l10n.gymPinWeight,
                unit: unit,
                canAdd: pinWeight != null && pinProblem == null,
                onChanged: (value) => setState(() => _pinWeight = value),
                onAdd: () {
                  gymSaved();
                  _set(GymEditorRules.addingPinWeight(_stack, pinWeight!));
                  setState(() {
                    _pinWeight = null;
                    _added++;
                  });
                },
              ),
              if (pinProblem != null)
                GymFormMessage(GymText.pinWeightProblem(l10n, pinProblem)),
            ],
          ],
        ),
        AppSection(
          header: l10n.gymAddOnWeights,
          footer: l10n.gymAddOnsFooter,
          children: [
            for (final (index, weight) in _stack.addOns.indexed)
              DeletableRow(
                id: 'addOn-$index-$weight',
                onDelete: () =>
                    _set(GymEditorRules.removingAddOns(_stack, {index})),
                child: AppListRow(
                  title: '+${GymText.weight(weight, _stack.unit)}',
                ),
              ),
            _AddField(
              key: ValueKey('addOn-$_added'),
              prompt: l10n.gymAddOnWeight,
              unit: unit,
              canAdd: addOn != null && addOnProblem == null,
              onChanged: (value) => setState(() => _addOn = value),
              onAdd: () {
                gymSaved();
                _set(GymEditorRules.addingAddOn(_stack, addOn!));
                setState(() {
                  _addOn = null;
                  _added++;
                });
              },
            ),
            if (addOnProblem != null)
              GymFormMessage(GymText.addOnProblem(l10n, addOnProblem)),
          ],
        ),
      ],
    );
  }
}

class _AddField extends StatelessWidget {
  const new({
    required this.prompt,
    required this.unit,
    required this.canAdd,
    required this.onChanged,
    required this.onAdd,
    super.key,
  });

  final String prompt;
  final String unit;
  final bool canAdd;
  final ValueChanged<double?> onChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppNumberField(
            value: null,
            prompt: prompt,
            unit: unit,
            onChanged: onChanged,
          ),
        ),
        AppTextButton(
          label: context.l10n.gymAdd,
          onPressed: canAdd ? onAdd : null,
        ),
      ],
    );
  }
}
