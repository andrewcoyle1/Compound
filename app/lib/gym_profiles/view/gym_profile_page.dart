import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/gym_profiles/cubit/gym_profile_editor_cubit.dart';
import 'package:compound/gym_profiles/view/gym_text.dart';
import 'package:compound/gym_profiles/view/gym_widgets.dart';
import 'package:compound/gym_profiles/view/machine_sheets.dart';
import 'package:compound/gym_profiles/view/stack_machine_editor.dart';
import 'package:compound/gym_profiles/view/weight_list_editor.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_repository/image_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// One gym's equipment (Swift `GymProfileView`): its name, every list of
/// equipment to switch on and off and edit, machines to add, duplicate and
/// delete. Leaving saves. With [continues], as when a gym is being set up,
/// Continue saves it, makes it the usual gym and pops with `true`.
class GymProfilePage extends StatelessWidget {
  const new({required this.gym, this.continues = false, super.key});

  final GymProfileModel gym;
  final bool continues;

  /// Pushes the editor on [gym].
  static Future<bool?> push(
    BuildContext context,
    GymProfileModel gym, {
    bool continues = false,
  }) => Navigator.of(context).push(
    MaterialPageRoute<bool>(
      builder: (_) => GymProfilePage(gym: gym, continues: continues),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    final l10n = context.l10n;
    return BlocProvider(
      create: (context) => GymProfileEditorCubit(
        gym: gym,
        uid: app.user.uid,
        setup: context.read<TrainingSetupService>(),
        analytics: context.read<AnalyticsRepository>(),
        images: context.read<ImageRepository>(),
        picker: context.read<PhotoPicker>(),
        untitledName: l10n.onboardingUntitledGym,
        numbered: l10n.gymNumberedName,
      ),
      child: GymProfileView(continues: continues),
    );
  }
}

class GymProfileView extends StatefulWidget {
  const new({this.continues = false, super.key});

  final bool continues;

  @override
  State<GymProfileView> createState() => _GymProfileViewState();
}

class _GymProfileViewState extends State<GymProfileView> {
  late final GymProfileEditorCubit _cubit = context
      .read<GymProfileEditorCubit>();
  late final _name = TextEditingController(text: _cubit.state.gym.name);
  late ScaffoldMessengerState _messenger;
  late String _saveFailed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
    _saveFailed = context.l10n.gymUnableToSave;
  }

  @override
  void dispose() {
    // Leaving saves, however the screen goes. It is gone by the time a save
    // fails, so the failure is told on the screen below.
    final messenger = _messenger;
    final saveFailed = _saveFailed;
    unawaited(
      _cubit.left().then((saved) {
        if (saved == null) return;
        if (saved) {
          unawaited(HapticFeedback.successNotification());
        } else {
          unawaited(HapticFeedback.errorNotification());
          messenger.showSnackBar(SnackBar(content: Text(saveFailed)));
        }
      }),
    );
    _name.dispose();
    super.dispose();
  }

  Future<void> _addMachine() async {
    final draft = await showGymSheet<GymMachineDraft>(
      context,
      const AddGymMachineSheet(),
    );
    if (draft == null || !mounted) return;
    final id = _cubit.addMachine(
      draft.list,
      name: draft.name,
      worksAs: draft.worksAs,
    );
    unawaited(openEquipmentEditor(context, draft.list, id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<GymProfileEditorCubit>().state;
    return BlocListener<GymProfileEditorCubit, GymProfileEditorState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) async {
        switch (state.status) {
          case GymProfileEditorStatus.continued:
            unawaited(HapticFeedback.successNotification());
            Navigator.of(context).pop(true);
          case GymProfileEditorStatus.continueFailure:
            unawaited(HapticFeedback.errorNotification());
            await showFailureAlert(
              context,
              l10n.onboardingUnableToSaveGym,
              l10n.gymCheckConnection,
            );
            _cubit.failureShown();
          case GymProfileEditorStatus.editing ||
              GymProfileEditorStatus.continuing:
            break;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            key: const Key('GymProfile.name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: l10n.onboardingUntitledGym,
              border: InputBorder.none,
              filled: false,
            ),
            onChanged: _cubit.renamed,
          ),
          actions: [
            IconButton(
              icon: const Icon(AppSymbols.add),
              tooltip: l10n.gymAddMachineMenu,
              onPressed: () => unawaited(_addMachine()),
            ),
            if (state.savingPhoto)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.m),
                child: SizedBox.square(
                  dimension: AppControlSize.icon,
                  child: CircularProgressIndicator.adaptive(),
                ),
              )
            else
              IconButton(
                key: const Key('GymProfile.photo'),
                icon: Icon(
                  state.gym.imageUrl == null
                      ? AppSymbols.addPhoto
                      : AppSymbols.changePhoto,
                ),
                tooltip: state.gym.imageUrl == null
                    ? l10n.gymAddPhoto
                    : l10n.gymChangePhoto,
                onPressed: () => unawaited(_cubit.photoPressed()),
              ),
          ],
        ),
        body: SafeArea(
          bottom: !widget.continues,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              // Swift's header falls back to the splash artwork, which the
              // Flutter app does not have; without a photo there is none.
              if (state.gym.imageUrl case final url?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.l,
                    AppSpacing.s,
                    AppSpacing.l,
                    0,
                  ),
                  child: StoredHeroImage(
                    url,
                    height: 300,
                    semanticLabel: l10n.gymPhoto,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  AppSpacing.s,
                  AppSpacing.l,
                  0,
                ),
                child: TextField(
                  key: const Key('GymProfile.search'),
                  decoration: InputDecoration(
                    hintText: l10n.gymFilterByName,
                    prefixIcon: const Icon(AppSymbols.search),
                  ),
                  onChanged: _cubit.queryChanged,
                ),
              ),
              GymListHeader(
                title: l10n.gymEquipment,
                trailing: SegmentedButton<GymEquipmentFilter>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: GymEquipmentFilter.all,
                      label: Text(l10n.gymFilterAll),
                    ),
                    ButtonSegment(
                      value: GymEquipmentFilter.selected,
                      label: Text(l10n.gymFilterSelected),
                    ),
                  ],
                  selected: {state.filter},
                  onSelectionChanged: (selection) =>
                      _cubit.filterChanged(selection.single),
                ),
              ),
              for (final list in GymEquipmentList.values)
                if (state.visible(list) case final items
                    when items.isNotEmpty) ...[
                  AppSection(
                    header: GymText.section(l10n, list),
                    children: [
                      for (final item in items)
                        _EquipmentRow(
                          key: ValueKey('${list.key}.${item.id}'),
                          list: list,
                          item: item,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.l),
                ],
              if (state.hidesEverything)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    l10n.searchNoResults(state.query.trim()),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.rowTitle,
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: widget.continues
            ? AppBottomCta(
                children: [
                  AppCtaButton(
                    label: l10n.onboardingContinue,
                    isLoading:
                        state.status == GymProfileEditorStatus.continuing,
                    onPressed: () => unawaited(_cubit.continuePressed()),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

/// Opens the editor of item [id] of [list]: a pushed list for weights and
/// stacks, a sheet for one weight.
Future<void> openEquipmentEditor(
  BuildContext context,
  GymEquipmentList list,
  String id,
) => switch (list) {
  GymEquipmentList.freeWeights ||
  GymEquipmentList.bodyWeights ||
  GymEquipmentList.bands ||
  GymEquipmentList.loadableBars ||
  GymEquipmentList.fixedWeightBars => pushGymPage<void>(
    context,
    WeightListEditorPage(list: list, itemId: id),
  ),
  GymEquipmentList.cableMachines ||
  GymEquipmentList.pinLoadedMachines => pushGymPage<void>(
    context,
    StackMachineEditorPage(list: list, machineId: id),
  ),
  GymEquipmentList.plateLoadedMachines => showGymSheet<void>(
    context,
    PlateLoadedMachineSheet(machineId: id),
  ),
  GymEquipmentList.loadableAccessoryEquipment => showGymSheet<void>(
    context,
    LoadableAccessorySheet(accessoryId: id),
  ),
  GymEquipmentList.supportEquipment ||
  GymEquipmentList.accessoryEquipment => Future.value(),
};

/// What a row shows under its name: the weights switched on, a machine's
/// stacks, a base weight.
String? _detail(
  AppLocalizations l10n,
  GymEquipmentList list,
  GymEquipmentItem item,
) => switch (item) {
  LoadableAccessoryEquipment(:final baseWeight, :final unit) => GymText.weight(
    baseWeight,
    unit,
  ),
  PlateLoadedMachine(:final baseWeight, :final unit, :final sleeves) =>
    sleeves == 1
        ? l10n.gymBaseOneSide(GymText.weight(baseWeight, unit))
        : GymText.weight(baseWeight, unit),
  StackMachine(:final ranges) => _stacks(l10n, ranges),
  PlainEquipment() => null,
  _ => GymText.activeWeights(GymEditorRules.allWeights(list, item)),
};

/// The stacks switched on, lightest first, a line each.
String _stacks(AppLocalizations l10n, List<WeightStack> ranges) {
  double lightestKg(WeightStack stack) {
    final lightest = stack.minWeight > 0 ? stack.minWeight : stack.increment;
    return stack.unit == ExerciseWeightUnit.pounds
        ? lightest / 2.20462
        : lightest;
  }

  final active = [...ranges.where((stack) => stack.isActive).indexed]
    ..sort((a, b) {
      final order = lightestKg(a.$2).compareTo(lightestKg(b.$2));
      return order != 0 ? order : a.$1.compareTo(b.$1);
    });
  return [for (final (_, stack) in active) GymText.stack(l10n, stack)]
      .join('\n');
}

/// One piece of equipment: its name, what is available, an edit link and
/// the switch that includes it in this gym. A machine also offers
/// Duplicate, and Delete when the user made it, on a long press.
class _EquipmentRow extends StatelessWidget {
  const new({required this.list, required this.item, super.key});

  final GymEquipmentList list;
  final GymEquipmentItem item;

  Future<void> _machineActions(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<GymProfileEditorCubit>();
    final action = await showModalBottomSheet<_MachineAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppSymbols.duplicate),
              title: Text(l10n.gymDuplicate),
              onTap: () => Navigator.of(context).pop(_MachineAction.duplicate),
            ),
            if (GymEditorRules.isCustom(list, item))
              ListTile(
                leading: Icon(
                  AppSymbols.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(l10n.gymDelete),
                onTap: () => Navigator.of(context).pop(_MachineAction.delete),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case _MachineAction.duplicate:
        cubit.duplicateMachine(list, item.id);
        unawaited(HapticFeedback.successNotification());
      case _MachineAction.delete:
        await _confirmDelete(context, cubit);
      case null:
        break;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    GymProfileEditorCubit cubit,
  ) async {
    final l10n = context.l10n;
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.gymDeleteMachineTitle),
        content: Text(
          l10n.gymDeleteMachineMessage(GymEditorRules.nameOf(item)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.gymCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.gymDelete),
          ),
        ],
      ),
    );
    if (delete ?? false) cubit.deleteMachine(list, item.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = GymEditorRules.nameOf(item);
    final detail = _detail(l10n, list, item);
    final editLink = GymText.editLink(l10n, list);
    final scheme = Theme.of(context).colorScheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.l,
        vertical: AppSpacing.s,
      ),
      child: Row(
        spacing: AppSpacing.m,
        children: [
          RowThumbnail(equipmentImage(item)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Text(name, style: AppTextStyles.rowTitle),
                if (detail != null && detail.isNotEmpty)
                  Text(
                    detail,
                    style: AppTextStyles.rowDetail.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (editLink != null)
                  TextButton(
                    key: Key('GymProfile.edit.${item.id}'),
                    onPressed: () =>
                        unawaited(openEquipmentEditor(context, list, item.id)),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(editLink),
                  ),
              ],
            ),
          ),
          Semantics(
            label: name,
            child: Switch.adaptive(
              key: Key('GymProfile.active.${item.id}'),
              value: item.isActive,
              onChanged: (isActive) => context
                  .read<GymProfileEditorCubit>()
                  .setActive(list, item.id, isActive: isActive),
            ),
          ),
        ],
      ),
    );
    if (!list.isMachine) return row;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.gymMachineActions): () =>
            unawaited(_machineActions(context)),
      },
      child: InkWell(
        onLongPress: () => unawaited(_machineActions(context)),
        child: row,
      ),
    );
  }
}

enum _MachineAction { duplicate, delete }

/// An item's bundled picture (Swift's `imageName` asset), scaled down from
/// the Swift app's in `assets/equipment/`; null for the many without one.
String? equipmentImage(GymEquipmentItem item) =>
    switch (item.toFirestore()[GymEquipmentKeys.imageName]) {
      final String name => 'assets/equipment/$name.webp',
      _ => null,
    };
