part of 'food_picker.dart';

// MARK: - Label

/// The label's secondary nutrients, in Swift's order.
const List<NutrientKey> _labelNutrients = [
  NutrientKey.fiber,
  NutrientKey.sugar,
  NutrientKey.fatSaturated,
  NutrientKey.sodiumMg,
  NutrientKey.potassiumMg,
  NutrientKey.calciumMg,
  NutrientKey.ironMg,
];

/// Label mode: the live camera reads a label on the device until it holds
/// still, then the AI reads its text into a food that Use This Food saves
/// to the library and puts on the plate. A photo's text, or text typed or
/// pasted (Swift's "Enter Label"), lands in the field to be checked before
/// Parse Label, as Swift waits for its Parse Label tap.
class _LabelView extends StatefulWidget {
  const new();

  @override
  State<_LabelView> createState() => _LabelViewState();
}

class _LabelViewState extends State<_LabelView> {
  final _text = TextEditingController();
  late final LabelScannerCubit _cubit = context.read();

  /// The camera is let go while the app is in the background or behind a
  /// system prompt, and opens again when it is back.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onInactive: () => unawaited(_cubit.pause()),
      onResume: () => unawaited(_cubit.resume()),
    );
    unawaited(_cubit.start());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = _cubit;
    final state = context.watch<LabelScannerCubit>().state;
    final food = switch (state.status) {
      LabelStatus.parsed ||
      LabelStatus.saving ||
      LabelStatus.saveFailed => state.food,
      _ => null,
    };
    final busy =
        state.status == LabelStatus.reading ||
        state.status == LabelStatus.parsing;
    return BlocListener<LabelScannerCubit, LabelScannerState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case LabelStatus.read:
            _text.text = state.text!;
            unawaited(AppHaptics.success());
          case LabelStatus.failed ||
              LabelStatus.saveFailed ||
              LabelStatus.unreadable:
            unawaited(AppHaptics.error());
          case LabelStatus.saved:
            // In the library now; on to its amount, as a found barcode is,
            // and the camera looks for the next label.
            _text.clear();
            unawaited(cubit.start());
            unawaited(pickFood(context, state.food!));
          case _:
        }
      },
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          if (food == null)
            AppViewfinder(
              key: const Key('FoodPicker.labelCamera'),
              preview: state.live ? context.read<LiveCamera>().preview() : null,
              caption: busy
                  ? l10n.labelReading
                  : state.status == LabelStatus.scanning
                  ? l10n.labelHoldInFrame
                  : null,
              busy: busy,
              action: state.hasTorch
                  ? Semantics(
                      toggled: state.torch,
                      child: AppIconButton(
                        icon: state.torch
                            ? AppSymbols.torchOn
                            : AppSymbols.torchOff,
                        semanticLabel: state.torch
                            ? l10n.torchTurnOff
                            : l10n.torchTurnOn,
                        onPressed: () => unawaited(cubit.toggleTorch()),
                      ),
                    )
                  : null,
            )
          else
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.s,
                  children: [
                    _LabelFoodSummary(food: food),
                    if (state.status == LabelStatus.saveFailed)
                      AppInlineMessage(
                        kind: AppInlineMessageKind.error,
                        text: l10n.labelSaveFailed,
                        kindLabel: l10n.addMealErrorLabel,
                      ),
                    Row(
                      spacing: AppSpacing.m,
                      children: [
                        Expanded(
                          child: AppCtaButton(
                            label: l10n.labelScanAgain,
                            variant: AppCtaVariant.secondary,
                            onPressed: () => unawaited(cubit.start()),
                          ),
                        ),
                        Expanded(
                          child: AppCtaButton(
                            label: l10n.labelUseFood,
                            isLoading: state.status == LabelStatus.saving,
                            onPressed: () => unawaited(cubit.use()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          if (_scanMessage(l10n, state) case final message?) ...[
            const SizedBox(height: AppSpacing.s),
            AppInlineMessage(
              kind: AppInlineMessageKind.error,
              text: message,
              kindLabel: l10n.addMealErrorLabel,
            ),
            if (state.camera == CameraState.denied)
              Center(
                child: AppTextButton(
                  label: l10n.labelOpenSettings,
                  onPressed: () => unawaited(cubit.openSettings()),
                ),
              ),
          ],
          if (food == null) ...[
            const SizedBox(height: AppSpacing.s),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.s,
              children: [
                if (!busy &&
                    state.status != LabelStatus.scanning &&
                    state.camera == CameraState.ready)
                  AppTextButton(
                    key: const Key('FoodPicker.labelScanAgain'),
                    label: l10n.labelScanAgain,
                    onPressed: () => unawaited(cubit.start()),
                  ),
                AppTextButton(
                  key: const Key('FoodPicker.labelChoosePhoto'),
                  label: l10n.labelChooseFromLibrary,
                  onPressed: busy
                      ? null
                      : () => unawaited(cubit.scan(PhotoSource.library)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            AppCard(
              child: AppTextFieldRow(
                key: const Key('FoodPicker.labelField'),
                label: l10n.labelField,
                controller: _text,
                minLines: 4,
                maxLines: 10,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              state.status == LabelStatus.read
                  ? l10n.labelCaptured
                  : l10n.labelScanHint,
              style: AppTextStyles.label.secondary(context),
            ),
            const SizedBox(height: AppSpacing.l),
            ValueListenableBuilder(
              valueListenable: _text,
              builder: (context, text, _) => AppCtaButton(
                label: l10n.labelParse,
                isLoading: state.status == LabelStatus.parsing,
                onPressed: text.text.trim().isEmpty
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        unawaited(cubit.parse(text.text));
                      },
              ),
            ),
            if (state.status == LabelStatus.failed) ...[
              const SizedBox(height: AppSpacing.m),
              AppInlineMessage(
                kind: AppInlineMessageKind.error,
                text: l10n.labelFailed,
                kindLabel: l10n.addMealErrorLabel,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Why the last scan gave no text, if it did not.
String? _scanMessage(AppLocalizations l10n, LabelScannerState state) =>
    switch ((state.status, state.camera)) {
      (_, CameraState.denied) => l10n.labelCameraOff,
      (_, CameraState.unavailable) => l10n.labelCameraUnavailable,
      (LabelStatus.unreadable, _) => l10n.labelUnreadable,
      _ => null,
    };

/// A label's food (Swift's parsed-ingredient card): its name and basis, its
/// calories and macros, and the other nutrients the label printed.
class _LabelFoodSummary extends StatelessWidget {
  const new({required this.food});

  final FoodModel food;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final values = food.nutrients.values;
    final macros = [
      if (values[NutrientKey.calories] case final kcal?)
        AppFormat.kcal(kcal.round()),
      if (values[NutrientKey.protein] case final grams?)
        l10n.nutritionItemProtein(AppFormat.grams(grams)),
      if (values[NutrientKey.fatTotal] case final grams?)
        l10n.nutritionItemFat(AppFormat.grams(grams)),
      if (values[NutrientKey.carbs] case final grams?)
        l10n.nutritionItemCarbs(AppFormat.grams(grams)),
    ].join(' · ');
    final others = [
      for (final key in _labelNutrients)
        if (values[key] case final value?)
          [
            nutrientFieldLabel(l10n, key),
            AppFormat.nutrient(value, unit: nutrientUnit(key)),
          ].join(': '),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(food.name, style: AppTextStyles.sectionTitle)),
            Text(
              food.measurementMethod == MeasurementMethod.volume
                  ? l10n.labelPer100ml
                  : l10n.labelPer100g,
              style: AppTextStyles.label.secondary(context),
            ),
          ],
        ),
        if (macros.isNotEmpty) Text(macros, style: AppTextStyles.rowDetail),
        if (others.isNotEmpty)
          Text(others, style: AppTextStyles.rowDetail.secondary(context)),
      ],
    );
  }
}
