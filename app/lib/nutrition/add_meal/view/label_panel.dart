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

/// Label mode: the label's text, typed or pasted (Swift's "Enter Label"),
/// is read by the AI into a food that Use This Food saves to the library
/// and puts on the plate. Reading the text from a photo is not built yet.
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
          case LabelStatus.failed || LabelStatus.saveFailed:
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
            l10n.labelHint,
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
                          child: OutlinedButton(
                            onPressed: cubit.dismiss,
                            child: Text(l10n.labelDismiss),
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
