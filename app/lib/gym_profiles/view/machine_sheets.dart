import 'package:app_ui/app_ui.dart';
import 'package:compound/gym_profiles/cubit/gym_profile_editor_cubit.dart';
import 'package:compound/gym_profiles/view/gym_widgets.dart';
import 'package:compound/gym_profiles/view/stack_machine_editor.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// A weight and its unit, edited in place (the base weight of a
/// plate-loaded machine or a loadable accessory).
class _WeightAndUnit extends StatelessWidget {
  const new({
    required this.value,
    required this.unit,
    required this.onValueChanged,
    required this.onUnitChanged,
  });

  final double value;
  final ExerciseWeightUnit unit;
  final ValueChanged<double> onValueChanged;
  final ValueChanged<ExerciseWeightUnit> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.s,
      children: [
        Text(l10n.gymWeights, style: AppTextStyles.sectionTitle),
        Row(
          spacing: AppSpacing.m,
          children: [
            Expanded(
              child: AppNumberField(
                value: value,
                prompt: '0',
                onChanged: (typed) => onValueChanged(typed ?? 0),
              ),
            ),
            WeightUnitSwitch(unit: unit, onChanged: onUnitChanged),
          ],
        ),
      ],
    );
  }
}

/// Swift's base for the two in-place sheets: reads item [id] of [list]
/// from the editor and writes each change back.
mixin _ItemSheet<T extends StatefulWidget> on State<T> {
  GymEquipmentList get list;
  String get id;

  late final GymProfileEditorCubit cubit = context
      .read<GymProfileEditorCubit>();

  void change(StoredMap Function(StoredMap data) edit) =>
      cubit.edit((gym) => GymEditorRules.updatingItem(gym, list, id, edit));
}

/// A plate-loaded machine's own weight, its unit, how many sleeves take
/// plates and whether sets count the plates alone (Swift
/// `EditPlateLoadedMachineView`). The user's own machines can be renamed.
class PlateLoadedMachineSheet extends StatefulWidget {
  const new({required this.machineId, super.key});

  final String machineId;

  @override
  State<PlateLoadedMachineSheet> createState() =>
      _PlateLoadedMachineSheetState();
}

class _PlateLoadedMachineSheetState extends State<PlateLoadedMachineSheet>
    with ScreenAnalytics, _ItemSheet {
  @override
  String get screen => 'EditPlateLoadedMachineView';

  @override
  GymEquipmentList get list => GymEquipmentList.plateLoadedMachines;

  @override
  String get id => widget.machineId;

  late final String _originalName = GymEditorRules.nameOf(
    GymEditorRules.item(cubit.state.gym, list, id)!,
  );

  @override
  void dispose() {
    // A machine left without a name keeps the one it had.
    final machine = GymEditorRules.item(cubit.state.gym, list, id);
    if (machine != null && GymEditorRules.nameOf(machine).trim().isEmpty) {
      cubit.edit(
        (gym) =>
            GymEditorRules.restoringBlankName(gym, list, id, _originalName),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final machine =
        GymEditorRules.item(watchGym(context), list, id) as PlateLoadedMachine?;
    if (machine == null) return const SizedBox.shrink();
    return GymSheet(
      title: machine.name,
      children: [
        if (GymEditorRules.isCustom(list, machine))
          MachineNameField(list: list, machine: machine),
        _WeightAndUnit(
          value: machine.baseWeight,
          unit: machine.unit,
          onValueChanged: (value) =>
              change((data) => {...data, GymEquipmentKeys.baseWeight: value}),
          onUnitChanged: (unit) =>
              change((data) => {...data, GymEquipmentKeys.unit: unit.value}),
        ),
        Text(l10n.gymPlatesGoOn, style: AppTextStyles.sectionTitle),
        // One side: a T-bar row or belt squat takes its plates on a single
        // post, so the smallest change is one plate rather than a pair.
        AppSegmentedControl<int>(
          segments: [
            AppSegment(value: 1, label: l10n.gymOneSide),
            AppSegment(value: 2, label: l10n.gymTwoSides),
          ],
          selected: machine.sleeves,
          onChanged: (sleeves) =>
              change((data) => {...data, GymEquipmentKeys.sleeves: sleeves}),
        ),
        AppSection(
          footer: l10n.gymPlatesOnlyFooter,
          children: [
            AppListRowToggle(
              title: l10n.gymPlatesOnly,
              value: machine.excludesBaseFromLoad,
              onChanged: (excludes) => change(
                (data) => {
                  ...data,
                  GymEquipmentKeys.excludesBaseFromLoad: excludes,
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// What a loadable accessory weighs empty, and its unit (Swift
/// `EditLoadableAccessoryView`); never below nothing.
class LoadableAccessorySheet extends StatefulWidget {
  const new({required this.accessoryId, super.key});

  final String accessoryId;

  @override
  State<LoadableAccessorySheet> createState() => _LoadableAccessorySheetState();
}

class _LoadableAccessorySheetState extends State<LoadableAccessorySheet>
    with ScreenAnalytics, _ItemSheet {
  @override
  String get screen => 'EditLoadableAccessoryView';

  @override
  GymEquipmentList get list => GymEquipmentList.loadableAccessoryEquipment;

  @override
  String get id => widget.accessoryId;

  @override
  Widget build(BuildContext context) {
    final accessory = GymEditorRules.item(
      watchGym(context),
      list,
      id,
    ) as LoadableAccessoryEquipment?;
    if (accessory == null) return const SizedBox.shrink();
    return GymSheet(
      title: accessory.name,
      children: [
        _WeightAndUnit(
          value: accessory.baseWeight,
          unit: accessory.unit,
          onValueChanged: (value) => change(
            (data) => {
              ...data,
              GymEquipmentKeys.baseWeight: value < 0 ? 0.0 : value,
            },
          ),
          onUnitChanged: (unit) =>
              change((data) => {...data, GymEquipmentKeys.unit: unit.value}),
        ),
      ],
    );
  }
}

/// What the Add Machine sheet hands back (Swift `GymMachineDraft`).
typedef GymMachineDraft = ({
  GymEquipmentList list,
  String name,
  String? worksAs,
});

/// Adding a machine (Swift `AddGymMachineView`): its kind, its name and,
/// optionally, the catalogue machine it works as. Pops with the draft, the
/// name trimmed, or nothing when closed.
class AddGymMachineSheet extends StatefulWidget {
  const new({super.key});

  /// The kinds offered, in order.
  static const List<GymEquipmentList> kinds = [
    GymEquipmentList.cableMachines,
    GymEquipmentList.pinLoadedMachines,
    GymEquipmentList.plateLoadedMachines,
  ];

  @override
  State<AddGymMachineSheet> createState() => _AddGymMachineSheetState();
}

class _AddGymMachineSheetState extends State<AddGymMachineSheet>
    with ScreenAnalytics {
  @override
  String get screen => 'AddGymMachineView';

  GymEquipmentList _kind = GymEquipmentList.cableMachines;
  String _name = '';
  String? _worksAs;

  String _kindTitle(AppLocalizations l10n, GymEquipmentList kind) =>
      switch (kind) {
        GymEquipmentList.cableMachines => l10n.gymKindCable,
        GymEquipmentList.pinLoadedMachines => l10n.gymKindPinLoaded,
        _ => l10n.gymKindPlateLoaded,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = _name.trim();
    final catalogue = [..._kind.catalogue]
      ..sort(
        (a, b) =>
            GymEditorRules.nameOf(a)
                .toLowerCase()
                .compareTo(GymEditorRules.nameOf(b).toLowerCase()),
      );
    return GymSheet(
      title: l10n.gymAddMachine,
      confirms: true,
      onConfirm: name.isEmpty
          ? null
          : () {
              gymSaved();
              Navigator.of(context).pop<GymMachineDraft>((
                list: _kind,
                name: name,
                worksAs: _worksAs,
              ));
            },
      children: [
        AppSegmentedControl<GymEquipmentList>(
          segments: [
            for (final kind in AddGymMachineSheet.kinds)
              AppSegment(value: kind, label: _kindTitle(l10n, kind)),
          ],
          selected: _kind,
          // The previous choice belongs to another kind's catalogue.
          onChanged: (kind) => setState(() {
            _kind = kind;
            _worksAs = null;
          }),
        ),
        AppTextField(
          label: l10n.gymName,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (name) => setState(() => _name = name),
        ),
        DropdownButtonFormField<String?>(
          key: ValueKey(_kind),
          initialValue: _worksAs,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.gymWorksAs,
            helperText: l10n.gymWorksAsFooter,
            helperMaxLines: 4,
          ),
          items: [
            DropdownMenuItem(child: Text(l10n.gymNone)),
            for (final machine in catalogue)
              DropdownMenuItem(
                value: machine.id,
                child: Text(GymEditorRules.nameOf(machine)),
              ),
          ],
          onChanged: (worksAs) => setState(() => _worksAs = worksAs),
        ),
      ],
    );
  }
}
