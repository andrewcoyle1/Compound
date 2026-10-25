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

/// The Swift module name of each weight list's screens, such as
/// `FreeWeight` for `EditFreeWeightView` and `AddFreeWeightView`.
String _module(GymEquipmentList list) => switch (list) {
  GymEquipmentList.freeWeights => 'FreeWeight',
  GymEquipmentList.bodyWeights => 'BodyWeight',
  GymEquipmentList.bands => 'Band',
  GymEquipmentList.loadableBars => 'LoadableBar',
  _ => 'FixedWeightBar',
};

/// The weights one piece of equipment holds, a unit at a time, each
/// switched on or off and swiped away to delete; the editor of free
/// weights, body weights, bands, loadable bars and fixed-weight bars
/// (Swift `EditFreeWeightView` and its four siblings, which differ only in
/// which fields a weight has). Loadable bars add their collars, plates a
/// count each.
class WeightListEditorPage extends StatefulWidget {
  const new({required this.list, required this.itemId, super.key});

  final GymEquipmentList list;
  final String itemId;

  @override
  State<WeightListEditorPage> createState() => _WeightListEditorPageState();
}

class _WeightListEditorPageState extends State<WeightListEditorPage>
    with ScreenAnalytics {
  @override
  String get screen => 'Edit${_module(widget.list)}View';

  late ExerciseWeightUnit _unit = GymEditorRules.openingUnit(
    widget.list,
    GymEditorRules.item(
      context.read<GymProfileEditorCubit>().state.gym,
      widget.list,
      widget.itemId,
    )!,
  );

  void _edit(GymProfileModel Function(GymProfileModel gym) change) =>
      context.read<GymProfileEditorCubit>().edit(change);

  Future<void> _add(GymEquipmentItem item) async {
    final entry = await showGymSheet<StoredMap>(
      context,
      AddWeightSheet(list: widget.list, item: item, unit: _unit),
    );
    if (entry == null) return;
    _edit(
      (gym) =>
          GymEditorRules.addingEntry(gym, widget.list, widget.itemId, entry),
    );
  }

  String _addLabel(AppLocalizations l10n) => switch (widget.list) {
    GymEquipmentList.freeWeights => l10n.gymAddFreeWeight,
    GymEquipmentList.bodyWeights => l10n.gymAddBodyWeight,
    GymEquipmentList.bands => l10n.gymAddBand,
    GymEquipmentList.loadableBars => l10n.gymAddLoadableBar,
    _ => l10n.gymAddFixedWeightBar,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = widget.list;
    final item = GymEditorRules.item(watchGym(context), list, widget.itemId);
    if (item == null) return AppScaffold(appBar: AppBar());
    final weights = GymEditorRules.weights(list, item, _unit);
    return AppScaffold(
      appBar: AppBar(
        title: Text(GymEditorRules.nameOf(item)),
        actions: [
          AppToolbarButton(
            icon: AppSymbols.add,
            semanticLabel: _addLabel(l10n),
            onPressed: () => unawaited(_add(item)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          // Cards inset from the edges, as every grouped list is.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.xl,
          ),
          children: [
            GymListHeader(
              title: l10n.gymWeights,
              trailing: WeightUnitSwitch(
                unit: _unit,
                onChanged: (unit) => setState(() => _unit = unit),
              ),
            ),
            if (weights.isEmpty)
              NoWeights(unit: _unit)
            else
              AppSection(
                children: [
                  for (final weight in weights)
                    DeletableRow(
                      id: weight.id,
                      onDelete: () => _edit(
                        (gym) => GymEditorRules.deletingEntries(
                          gym,
                          list,
                          widget.itemId,
                          {weight.id},
                        ),
                      ),
                      child: _WeightRow(
                        list: list,
                        item: item,
                        weight: weight,
                        onEdit: (edit) => _edit(
                          (gym) => GymEditorRules.updatingEntry(
                            gym,
                            list,
                            widget.itemId,
                            weight.id,
                            edit,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            if (item case final LoadableBars bar) ...[
              const SizedBox(height: AppSpacing.xl),
              AppSection(
                header: l10n.gymCollars,
                footer: l10n.gymCollarsFooter,
                children: [
                  AppNumberField(
                    key: ValueKey(_unit),
                    value: GymEditorRules.collarShown(bar, _unit),
                    prompt: '0',
                    label: l10n.gymEachCollar,
                    unit: WorkoutText.weightUnit(_unit).symbol,
                    onChanged: (value) => _edit(
                      (gym) => GymEditorRules.updatingItem(
                        gym,
                        list,
                        widget.itemId,
                        (data) => {
                          ...data,
                          GymEquipmentKeys.collarWeight:
                              GymEditorRules.collarStored(value, _unit),
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeightRow extends StatelessWidget {
  const new({
    required this.list,
    required this.item,
    required this.weight,
    required this.onEdit,
  });

  final GymEquipmentList list;
  final GymEquipmentItem item;
  final WeightEntry weight;
  final void Function(StoredMap Function(StoredMap entry) edit) onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final figure = GymText.weight(weight.value, weight.unit);
    final colour = AppColors.fromHex(weight.colour);
    final name = weight.name;
    final title = list == GymEquipmentList.bands && name != null
        ? name
        : figure;
    final isPlates = item is FreeWeights && (item as FreeWeights).isPlates;
    return Column(
      children: [
        AppListRow(
          title: title,
          subtitle: list == GymEquipmentList.bands
              ? l10n.gymUpTo(figure)
              : null,
          thumbnail: colour == null
              ? null
              : AppSwatch(color: colour, size: AppIconSize.medium),
          accessory: AppListRowCustom(
            Switch.adaptive(
              value: weight.isActive,
              onChanged: (isActive) => onEdit(
                (entry) => {...entry, GymEquipmentKeys.isActive: isActive},
              ),
            ),
          ),
        ),
        // Plates run out: with two 20s the calculator must reach for the
        // 15s.
        if (isPlates)
          AppNumberField(
            value: weight.count?.toDouble(),
            prompt: l10n.gymNoLimit,
            label: l10n.gymHowMany,
            onChanged: (value) => onEdit((entry) {
              final count = GymEditorRules.plateCount(value);
              return {...entry, GymEquipmentKeys.count: count}
                ..removeWhere((key, value) => value == null);
            }),
          ),
      ],
    );
  }
}

/// Adding one weight to a weight list (Swift `AddFreeWeightView` and its
/// four siblings), in the unit the list was showing. Pops with the new
/// weight's stored map, or nothing when closed.
class AddWeightSheet extends StatefulWidget {
  const new({
    required this.list,
    required this.item,
    required this.unit,
    super.key,
  });

  final GymEquipmentList list;
  final GymEquipmentItem item;
  final ExerciseWeightUnit unit;

  @override
  State<AddWeightSheet> createState() => _AddWeightSheetState();
}

class _AddWeightSheetState extends State<AddWeightSheet> with ScreenAnalytics {
  @override
  String get screen => 'Add${_module(widget.list)}View';

  double _value = 0;
  double? _count;
  String _name = '';
  EquipmentColour _colour = EquipmentColour.standard;

  bool get _isBands => widget.list == GymEquipmentList.bands;

  bool get _needsColour =>
      _isBands || (widget.item is FreeWeights && _freeWeights.needsColour);

  FreeWeights get _freeWeights => widget.item as FreeWeights;

  bool get _isPlates => widget.item is FreeWeights && _freeWeights.isPlates;

  AddWeightProblem? get _problem => GymEditorRules.addWeightProblem(
    widget.list,
    widget.item,
    value: _value,
    unit: widget.unit,
    count: GymEditorRules.plateCount(_count),
    name: _name,
  );

  void _save() {
    if (_problem != null) return;
    Navigator.of(context).pop(
      GymEditorRules.newWeight(
        widget.list,
        id: newDocumentId(),
        value: _value,
        unit: widget.unit,
        colour: _needsColour ? _colour.hex : null,
        name: _name,
        count: GymEditorRules.plateCount(_count),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final problem = _problem;
    return GymSheet(
      title: l10n.gymAdd,
      subtitle: GymEditorRules.nameOf(widget.item),
      confirms: true,
      onConfirm: problem == null ? _save : null,
      children: [
        if (_needsColour)
          EquipmentColourPicker(
            title: _isBands ? l10n.gymBandColour : l10n.gymPlateColour,
            selected: _colour,
            onSelected: (colour) => setState(() => _colour = colour),
          ),
        if (_isBands)
          AppTextField(
            label: l10n.gymLabel,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (name) => setState(() => _name = name),
          ),
        AppNumberField(
          value: null,
          prompt: '0',
          label: l10n.gymWeight,
          unit: WorkoutText.weightUnit(widget.unit).symbol,
          onChanged: (value) => setState(() => _value = value ?? 0),
        ),
        // Empty is no limit, which is what every plate meant before counts
        // existed.
        if (_isPlates) ...[
          AppNumberField(
            value: null,
            prompt: l10n.gymNoLimit,
            label: l10n.gymHowMany,
            onChanged: (value) => setState(() => _count = value),
          ),
          Text(l10n.gymPairsFooter, style: AppTextStyles.rowDetail),
        ],
        if (problem != null)
          GymFormMessage(GymText.addWeightProblem(l10n, problem)),
      ],
    );
  }
}

/// The swatch row the Add Band and Add Free Weight sheets colour-code with
/// (Swift `EquipmentColourPicker`): each swatch a button named after its
/// colour, marked when selected.
class EquipmentColourPicker extends StatelessWidget {
  const new({
    required this.title,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String title;
  final EquipmentColour selected;
  final ValueChanged<EquipmentColour> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.s,
      children: [
        Text(title, style: AppTextStyles.sectionTitle),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: [
            for (final colour in EquipmentColour.values)
              Semantics(
                button: true,
                selected: colour == selected,
                label: colour.label(l10n),
                excludeSemantics: true,
                child: AppPressable(
                  shape: const CircleBorder(),
                  onTap: () => onSelected(colour),
                  child: AppSwatch(
                    color: colour == EquipmentColour.standard
                        ? scheme.onSurface
                        : AppColors.fromHex(colour.hex) ?? scheme.onSurface,
                    selected: colour == selected,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
