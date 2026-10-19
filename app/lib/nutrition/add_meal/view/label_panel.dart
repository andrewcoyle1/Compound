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

/// Label mode: the label's text, read on the device from a photo (Swift's
/// live text scanner) or typed or pasted (Swift's "Enter Label"), is read
/// by the AI into a food that Use This Food saves to the library and puts
/// on the plate. The photo's text lands in the field first, to be checked
/// before Parse Label, as Swift waits for its Parse Label tap.
class _LabelView extends StatefulWidget {
  const new();

  @override
  State<_LabelView> createState() => _LabelViewState();
}

class _LabelViewState extends State<_LabelView> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<LabelScannerCubit>();
    final state = context.watch<LabelScannerCubit>().state;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final food = switch (state.status) {
      LabelStatus.parsed ||
      LabelStatus.saving ||
      LabelStatus.saveFailed => state.food,
      _ => null,
    };
    return BlocListener<LabelScannerCubit, LabelScannerState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case LabelStatus.read:
            _text.text = state.text!;
            unawaited(HapticFeedback.successNotification());
          case LabelStatus.failed ||
              LabelStatus.saveFailed ||
              LabelStatus.unreadable:
            unawaited(HapticFeedback.errorNotification());
          case LabelStatus.saved:
            // In the library now; on to its amount, as a found barcode is.
            _text.clear();
            cubit.dismiss();
            unawaited(pickFood(context, state.food!));
          case _:
        }
      },
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          if (state.status == LabelStatus.reading)
            _Working(l10n.labelReading)
          else
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.s,
              children: [
                AppCtaButton(
                  key: const Key('FoodPicker.scanLabel'),
                  label: l10n.labelScan,
                  size: AppCtaSize.compact,
                  variant: AppCtaVariant.secondary,
                  onPressed: () => unawaited(cubit.scan(PhotoSource.camera)),
                ),
                AppTextButton(
                  label: l10n.labelChooseFromLibrary,
                  onPressed: () => unawaited(cubit.scan(PhotoSource.library)),
                ),
              ],
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
          const SizedBox(height: AppSpacing.m),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: TextField(
                key: const Key('FoodPicker.labelField'),
                controller: _text,
                minLines: 4,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: l10n.labelField,
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            state.status == LabelStatus.read
                ? l10n.labelCaptured
                : l10n.labelScanHint,
            style: AppTextStyles.label.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.l),
          if (food == null)
            if (state.status == LabelStatus.parsing)
              _Working(l10n.labelAnalyzing)
            else ...[
              ValueListenableBuilder(
                valueListenable: _text,
                builder: (context, text, _) => AppCtaButton(
                  label: l10n.labelParse,
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
            ]
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
                            label: l10n.labelDismiss,
                            variant: AppCtaVariant.secondary,
                            onPressed: cubit.dismiss,
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
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
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
              style: AppTextStyles.label.copyWith(color: secondary),
            ),
          ],
        ),
        if (macros.isNotEmpty) Text(macros, style: AppTextStyles.rowDetail),
        if (others.isNotEmpty)
          Text(
            others,
            style: AppTextStyles.rowDetail.copyWith(color: secondary),
          ),
      ],
    );
  }
}
