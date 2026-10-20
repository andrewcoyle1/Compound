import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/view/check_in_page.dart'
    show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/add_meal/view/barcode_camera.dart';
import 'package:compound/nutrition/add_meal/view/food_picker.dart'
    show enterBarcode;
import 'package:compound/nutrition/foods/cubit/create_food_cubit.dart';
import 'package:compound/nutrition/foods/logic/create_food.dart';
import 'package:compound/nutrition/logic/meal_logging.dart' show EnergyUnit;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:image_repository/image_repository.dart';

/// Creating a food (Swift `CreateFoodView`, then `PortionDefinitionView` and
/// `FoodDefinitionView`, pushed with the same cubit). Over the tabs, as the
/// Swift app's sheet. Closes with the food created when it was opened to
/// add to a plate and Create & Add was pressed; otherwise with null.
class CreateFoodPage extends StatelessWidget {
  const new({this.addToPlate = false, super.key});

  static const path = '/create-food';
  static const name = 'createFood';

  /// The query parameter set when a plate is waiting for the food.
  static const addParameter = 'add';

  /// Opens the flow from the library.
  static Future<void> show(BuildContext context) =>
      context.pushNamed<void>(name);

  /// Opens the flow from the meal logger: Create & Add closes it with the
  /// food created.
  static Future<FoodModel?> showForPlate(BuildContext context) =>
      context.pushNamed<FoodModel>(name, queryParameters: {addParameter: '1'});

  /// Whether Create & Add is offered (`FoodDefinitionPresenter
  /// .canAddToPlate`).
  final bool addToPlate;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    return BlocProvider(
      create: (context) => CreateFoodCubit(
        uid: app is AppAuthenticated ? app.user.uid : null,
        foods: context.read<FoodRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        images: context.read<ImageRepository>(),
        picker: context.read<PhotoPicker>(),
      ),
      child: CreateFoodView(addToPlate: addToPlate),
    );
  }
}

/// Logs a step appearing and going, under its Swift view's name.
mixin _TrackedStep<T extends StatefulWidget> on State<T> {
  String get screen;
  late final CreateFoodCubit cubit;

  @override
  void initState() {
    super.initState();
    cubit = context.read<CreateFoodCubit>()..appeared(screen);
  }

  @override
  void dispose() {
    cubit.disappeared(screen);
    super.dispose();
  }
}

/// The food's picture (`CreateFoodView.imageSection`): the photo picked, or
/// a meal glyph with an edit badge, opening the photo library.
class _FoodImageButton extends StatelessWidget {
  const new({required this.photo});

  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    final side = MediaQuery.textScalerOf(context).scale(120);
    final photo = this.photo;
    return Center(
      child: Semantics(
        button: true,
        label: context.l10n.createFoodChooseImage,
        excludeSemantics: true,
        child: InkWell(
          key: const Key('CreateFood.image'),
          customBorder: const CircleBorder(),
          onTap: () =>
              unawaited(context.read<CreateFoodCubit>().photoPressed()),
          child: SizedBox.square(
            dimension: side,
            child: photo != null
                ? ClipOval(
                    child: Image.memory(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const AppIconBadge(
                        icon: AppSymbols.meal,
                        size: AppIconSize.hero,
                        filled: false,
                      ),
                    ),
                  )
                // Swift's `fork.knife.circle` with a pencil badge.
                : const Center(
                    child: AppIconBadge(
                      icon: AppSymbols.meal,
                      size: AppIconSize.hero,
                      filled: false,
                      badge: AppSymbols.edit,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Pushes a later step, sharing the flow's cubit.
Future<void> _pushStep(BuildContext context, Widget page) {
  final cubit = context.read<CreateFoodCubit>();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(value: cubit, child: page),
    ),
  );
}

/// The name, brand and barcode.
class CreateFoodView extends StatefulWidget {
  const new({required this.addToPlate, super.key});

  final bool addToPlate;

  @override
  State<CreateFoodView> createState() => _CreateFoodViewState();
}

class _CreateFoodViewState extends State<CreateFoodView>
    with _TrackedStep<CreateFoodView> {
  @override
  String get screen => 'CreateFoodView';

  /// Closing asks first when there is something to lose
  /// (`CreateFoodPresenter.onCancelPressed`).
  Future<void> _close() async {
    if (cubit.state.hasUnsavedChanges) {
      final l10n = context.l10n;
      final discard = await AppDialog.confirmDestructive(
        context,
        title: l10n.createFoodDiscardTitle,
        confirmLabel: l10n.createFoodDiscard,
      );
      if (!discard || !mounted) return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _scan() async {
    final code = await showAppSheet<String>(
      context: context,
      builder: (_) => const _BarcodeSheet(),
    );
    if (code != null) cubit.barcodeScanned(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CreateFoodCubit>().state;
    final barcode = state.barcode;
    InputDecoration field(String hint) => InputDecoration(
      hintText: hint,
      border: InputBorder.none,
      filled: false,
    );
    return PopScope(
      canPop: !state.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: AppScaffold(
        appBar: AppBar(
          leading: AppToolbarButton.close(
            semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: _close,
          ),
          title: Text(l10n.createFoodTitle),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            _FoodImageButton(photo: state.photo),
            const SizedBox(height: AppSpacing.l),
            AppSection(
              header: l10n.createFoodName,
              trailing: Text(l10n.createFoodRequired),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  // Not focused on opening, so the keyboard does not hide
                  // the form (as Swift).
                  child: TextField(
                    key: const Key('CreateFood.name'),
                    textCapitalization: TextCapitalization.words,
                    decoration: field(l10n.createFoodNamePrompt),
                    onChanged: cubit.nameChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            AppSection(
              header: l10n.createFoodBrand,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  child: TextField(
                    key: const Key('CreateFood.brand'),
                    textCapitalization: TextCapitalization.words,
                    decoration: field(l10n.createFoodNamePrompt),
                    onChanged: cubit.brandChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            AppSection(
              header: l10n.createFoodBarcode,
              children: [
                if (barcode == null)
                  AppListRowButton(
                    title: l10n.createFoodScanBarcode,
                    icon: AppSymbols.barcode,
                    accessory: null,
                    onPressed: _scan,
                  )
                else
                  AppListRowButton(
                    title: barcode,
                    icon: AppSymbols.barcode,
                    accessory: null,
                    onPressed: _scan,
                  ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: AppBottomCta(
          children: [
            AppCtaButton(
              key: const Key('CreateFood.next'),
              label: l10n.createFoodNext,
              onPressed: state.canContinue
                  ? () => _pushStep(
                      context,
                      PortionDefinitionView(addToPlate: widget.addToPlate),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// The camera, or the barcode typed; closes with the code
/// (`BarcodeScannerView` in its barcode-only mode).
class _BarcodeSheet extends StatefulWidget {
  const new();

  @override
  State<_BarcodeSheet> createState() => _BarcodeSheetState();
}

class _BarcodeSheetState extends State<_BarcodeSheet> {
  // The camera reports a code it can see many times a second.
  bool _closed = false;

  void _close(String code) {
    if (_closed || code.trim().isEmpty) return;
    _closed = true;
    unawaited(AppHaptics.success());
    Navigator.of(context).pop(code.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.m,
        children: [
          Text(l10n.createFoodScanBarcode, style: AppTextStyles.sectionTitle),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.l),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: BarcodeCamera(onDetect: _close),
            ),
          ),
          Text(
            l10n.addMealBarcodeHint,
            textAlign: TextAlign.center,
            style: AppTextStyles.rowDetail,
          ),
          AppTextButton(
            label: l10n.addMealBarcodeEnter,
            onPressed: () async {
              final code = await enterBarcode(context, null);
              if (code != null && mounted) _close(code);
            },
          ),
        ],
      ),
    );
  }
}

/// The serving the figures describe (Swift `PortionDefinitionView`, its
/// serving option, the only one offered).
class PortionDefinitionView extends StatefulWidget {
  const new({required this.addToPlate, super.key});

  final bool addToPlate;

  @override
  State<PortionDefinitionView> createState() => _PortionDefinitionViewState();
}

class _PortionDefinitionViewState extends State<PortionDefinitionView>
    with _TrackedStep<PortionDefinitionView> {
  @override
  String get screen => 'PortionDefinitionView';

  late final _portionName = TextEditingController(
    text: cubit.state.portionName,
  );

  @override
  void dispose() {
    _portionName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CreateFoodCubit>().state;
    return AppScaffold(
      appBar: AppBar(title: Text(l10n.createFoodTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            header: l10n.createFoodServingHeader,
            footer: l10n.createFoodServingFooter,
            children: [
              AppNumberField(
                key: const Key('PortionDefinition.weight'),
                label: l10n.createFoodServingWeight,
                prompt: l10n.createFoodServingWeightPrompt,
                unit: 'g',
                value: state.servingWeight,
                onChanged: cubit.servingWeightChanged,
              ),
              AppNumberField(
                key: const Key('PortionDefinition.quantity'),
                label: l10n.createFoodPortionQuantity,
                prompt: '1',
                value: state.portionSize,
                onChanged: cubit.portionSizeChanged,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                child: Row(
                  spacing: AppSpacing.m,
                  children: [
                    Text(
                      l10n.createFoodPortionName,
                      style: AppTextStyles.rowTitle,
                    ),
                    Expanded(
                      child: TextField(
                        key: const Key('PortionDefinition.name'),
                        controller: _portionName,
                        textAlign: TextAlign.end,
                        decoration: const InputDecoration(
                          hintText: 'portion',
                          border: InputBorder.none,
                          filled: false,
                        ),
                        onChanged: cubit.portionNameChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          AppInlineMessage(
            kind: AppInlineMessageKind.info,
            text: l10n.createFoodServingInfo,
            kindLabel: l10n.infoLabel,
          ),
        ],
      ),
      bottomNavigationBar: AppBottomCta(
        children: [
          AppCtaButton(
            key: const Key('PortionDefinition.next'),
            label: l10n.createFoodNext,
            onPressed: state.canContinuePortionStep
                ? () => _pushStep(
                    context,
                    FoodDefinitionView(addToPlate: widget.addToPlate),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// The nutrition facts (Swift `FoodDefinitionView`): energy and the macros
/// open, every other nutrient in a closed group, each in the unit it is
/// stored in.
class FoodDefinitionView extends StatefulWidget {
  const new({required this.addToPlate, super.key});

  final bool addToPlate;

  @override
  State<FoodDefinitionView> createState() => _FoodDefinitionViewState();
}

class _FoodDefinitionViewState extends State<FoodDefinitionView>
    with _TrackedStep<FoodDefinitionView> {
  @override
  String get screen => 'FoodDefinitionView';

  Future<void> _done(CreateFoodState state) async {
    if (state.status == CreateFoodStatus.created) {
      unawaited(AppHaptics.success());
      // Every step of the flow, its first included.
      Navigator.of(context)
        ..popUntil(
          (route) =>
              route.settings.name == CreateFoodPage.name || route.isFirst,
        )
        ..pop(state.addToPlate ? state.created : null);
      return;
    }
    unawaited(AppHaptics.error());
    final l10n = context.l10n;
    await showFailureAlert(
      context,
      l10n.createFoodFailed,
      l10n.createFoodFailedMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CreateFoodCubit>().state;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final portionSize = state.portionSize;
    Widget group(NutrientGroup group, {List<Widget> leading = const []}) =>
        AppCard(
          child: ExpansionTile(
            key: Key('FoodDefinition.${group.name}'),
            initiallyExpanded: group == NutrientGroup.macros,
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              groupTitle(l10n, group),
              style: AppTextStyles.sectionTitle,
            ),
            children: [
              ...leading,
              for (final field in nutrientFields)
                if (field.group == group)
                  AppNumberField(
                    key: Key('FoodDefinition.${field.key.value}'),
                    label: nutrientFieldLabel(l10n, field.key),
                    prompt: '0',
                    unit: nutrientUnit(field.key),
                    value: state.nutrients[field.key],
                    onChanged: (value) =>
                        cubit.nutrientChanged(field.key, value),
                  ),
            ],
          ),
        );
    return BlocListener<CreateFoodCubit, CreateFoodState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          (current.status == CreateFoodStatus.created ||
              current.status == CreateFoodStatus.failed),
      listener: (_, state) => unawaited(_done(state)),
      child: AppScaffold(
        appBar: AppBar(title: Text(l10n.createFoodTitle)),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.l),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xxs,
                children: [
                  Text(
                    l10n.createFoodFactsHeader(
                      l10n.createFoodServing.toLowerCase(),
                    ),
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: secondary,
                    ),
                  ),
                  if (portionSize != null && state.portionName.isNotEmpty)
                    Text(
                      l10n.createFoodServingSize(
                        AppFormat.number(portionSize, maxFractionDigits: 2),
                        state.portionName,
                      ),
                      style: AppTextStyles.label.copyWith(color: secondary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            for (final value in NutrientGroup.values) ...[
              group(
                value,
                leading: [
                  if (value == NutrientGroup.macros)
                    AppNumberField.units(
                      key: const Key('FoodDefinition.energy'),
                      label: l10n.createFoodEnergy,
                      prompt: '0',
                      value: state.energy,
                      onChanged: cubit.energyChanged,
                      unit: state.energyUnit.symbol,
                      units: [
                        for (final unit in EnergyUnit.values) unit.symbol,
                      ],
                      unitsLabel: l10n.createFoodUnit,
                      onUnitChanged: (symbol) => cubit.energyUnitChanged(
                        EnergyUnit.values.firstWhere(
                          (unit) => unit.symbol == symbol,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
            ],
          ],
        ),
        bottomNavigationBar: AppBottomCta(
          children: [
            if (widget.addToPlate)
              AppCtaButton(
                key: const Key('FoodDefinition.createAndAdd'),
                label: l10n.createFoodCreateAndAdd,
                isLoading: state.isSaving && state.addToPlate,
                onPressed: state.canCreate && !state.isSaving
                    ? () => unawaited(cubit.create(addToPlate: true))
                    : null,
              ),
            AppCtaButton(
              key: const Key('FoodDefinition.create'),
              label: l10n.createFoodCreate,
              variant: widget.addToPlate
                  ? AppCtaVariant.secondary
                  : AppCtaVariant.primary,
              isLoading: state.isSaving && !state.addToPlate,
              onPressed: state.canCreate && !state.isSaving
                  ? () => unawaited(cubit.create())
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A nutrient group's title on the form.
String groupTitle(AppLocalizations l10n, NutrientGroup group) =>
    switch (group) {
      NutrientGroup.macros => l10n.createFoodMacros,
      NutrientGroup.carbs => l10n.createFoodCarbsBreakdown,
      NutrientGroup.fats => l10n.createFoodFatsBreakdown,
      NutrientGroup.proteins => l10n.createFoodProteinBreakdown,
      NutrientGroup.vitamins => l10n.createFoodVitaminsBreakdown,
      NutrientGroup.minerals => l10n.createFoodMineralsBreakdown,
      NutrientGroup.other => l10n.createFoodOther,
    };

/// A nutrient field's label on the form (Swift `FoodDefinitionView`'s row
/// labels). Only the keys in `nutrientFields` are asked for.
String nutrientFieldLabel(AppLocalizations l10n, NutrientKey key) =>
    switch (key) {
      NutrientKey.protein => l10n.foodFieldProtein,
      NutrientKey.carbs => l10n.foodFieldCarbs,
      NutrientKey.fatTotal => l10n.foodFieldFats,
      NutrientKey.fiber => l10n.foodFieldFiber,
      NutrientKey.starch => l10n.foodFieldStarch,
      NutrientKey.sugar => l10n.foodFieldSugars,
      NutrientKey.addedSugars => l10n.foodFieldAddedSugars,
      NutrientKey.fatMonounsaturated => l10n.foodFieldMonounsaturatedFat,
      NutrientKey.fatPolyunsaturated => l10n.foodFieldPolyunsaturatedFat,
      NutrientKey.omega3 => l10n.foodFieldOmega3,
      NutrientKey.omega3Ala => l10n.foodFieldOmega3Ala,
      NutrientKey.omega3Dha => l10n.foodFieldOmega3Dha,
      NutrientKey.omega3Epa => l10n.foodFieldOmega3Epa,
      NutrientKey.omega6 => l10n.foodFieldOmega6,
      NutrientKey.fatSaturated => l10n.foodFieldSaturatedFat,
      NutrientKey.fatTrans => l10n.foodFieldTransFat,
      NutrientKey.cysteine => l10n.foodFieldCysteine,
      NutrientKey.histidine => l10n.foodFieldHistidine,
      NutrientKey.isoleucine => l10n.foodFieldIsoleucine,
      NutrientKey.leucine => l10n.foodFieldLeucine,
      NutrientKey.lysine => l10n.foodFieldLysine,
      NutrientKey.methionine => l10n.foodFieldMethionine,
      NutrientKey.phenylalanine => l10n.foodFieldPhenylalanine,
      NutrientKey.threonine => l10n.foodFieldThreonine,
      NutrientKey.tryptophan => l10n.foodFieldTryptophan,
      NutrientKey.tyrosine => l10n.foodFieldTyrosine,
      NutrientKey.valine => l10n.foodFieldValine,
      NutrientKey.thiaminMg => l10n.foodFieldThiamine,
      NutrientKey.riboflavinMg => l10n.foodFieldRiboflavin,
      NutrientKey.niacinMg => l10n.foodFieldNiacin,
      NutrientKey.pantothenicAcidMg => l10n.foodFieldPantothenicAcid,
      NutrientKey.vitaminB6Mg => l10n.foodFieldPyridoxine,
      NutrientKey.vitaminB12Mcg => l10n.foodFieldCobalamin,
      NutrientKey.folateMcg => l10n.foodFieldFolate,
      NutrientKey.vitaminAMcg => l10n.foodFieldVitaminA,
      NutrientKey.vitaminCMg => l10n.foodFieldVitaminC,
      NutrientKey.vitaminDMcg => l10n.foodFieldVitaminD,
      NutrientKey.vitaminEMg => l10n.foodFieldVitaminE,
      NutrientKey.vitaminKMcg => l10n.foodFieldVitaminK,
      NutrientKey.calciumMg => l10n.foodFieldCalcium,
      NutrientKey.copperMg => l10n.foodFieldCopper,
      NutrientKey.ironMg => l10n.foodFieldIron,
      NutrientKey.magnesiumMg => l10n.foodFieldMagnesium,
      NutrientKey.manganeseMg => l10n.foodFieldManganese,
      NutrientKey.phosphorusMg => l10n.foodFieldPhosphorus,
      NutrientKey.potassiumMg => l10n.foodFieldPotassium,
      NutrientKey.seleniumMcg => l10n.foodFieldSelenium,
      NutrientKey.sodiumMg => l10n.foodFieldSodium,
      NutrientKey.zincMg => l10n.foodFieldZinc,
      NutrientKey.alcohol => l10n.foodFieldAlcohol,
      NutrientKey.caffeineMg => l10n.foodFieldCaffeine,
      NutrientKey.cholesterolMg => l10n.foodFieldCholesterol,
      NutrientKey.water => l10n.foodFieldWater,
      _ => key.value,
    };
