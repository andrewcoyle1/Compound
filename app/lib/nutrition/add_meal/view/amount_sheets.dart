import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/add_meal/cubit/amount_cubit.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_repository/food_repository.dart';

/// What the food amount sheet closed with: the item to add, and whether to
/// log the plate straight after.
typedef FoodAmountResult = ({MealItemModel item, bool log});

/// The amount of [food] to log (Swift `IngredientAmountView`), opening on
/// its own portion. Null when dismissed.
Future<FoodAmountResult?> showFoodAmountSheet(
  BuildContext context,
  FoodModel food,
) => showModalBottomSheet<FoodAmountResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => BlocProvider(
    create: (_) => AmountCubit(initialAmount(food)),
    child: FoodAmountSheet(food: food),
  ),
);

/// A plate item's amount, corrected (Swift `MealItemAmountViewView`). Null
/// when dismissed.
Future<MealItemModel?> showItemAmountSheet(
  BuildContext context,
  MealItemModel item,
) => showModalBottomSheet<MealItemModel>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => BlocProvider(
    create: (_) => AmountCubit(AmountState(text: amountText(item.amount))),
    child: ItemAmountSheet(item: item),
  ),
);

class FoodAmountSheet extends StatelessWidget {
  const new({required this.food, super.key});

  final FoodModel food;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AmountCubit>().state;
    final macros = foodAmountMacros(food, state);
    final units = food.servingUnits;
    final valid = state.amount > 0;
    // Read when pressed, so the last keystroke always counts.
    void close({required bool log}) {
      final now = context.read<AmountCubit>().state;
      Navigator.of(context)
          .pop((item: food.mealItem(now.amount, unit: now.unit), log: log));
    }

    return _SheetBody(
      title: food.name,
      subtitle: food.brandName,
      field: _AmountField(
        unit: units.isEmpty
            ? Text(food.loggedUnitLabel)
            : DropdownButton<String>(
                value: state.unit?.name ?? '',
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(food.loggedUnitLabel),
                  ),
                  for (final unit in units)
                    DropdownMenuItem(value: unit.name, child: Text(unit.name)),
                ],
                onChanged: (name) => context.read<AmountCubit>().unitChanged(
                  units.where((unit) => unit.name == name).firstOrNull,
                ),
              ),
      ),
      macros: (
        calories: macros.calories,
        protein: macros.protein,
        carbs: macros.carbs,
        fat: macros.fat,
      ),
      buttons: [
        AppCtaButton(
          label: l10n.addMealLog,
          onPressed: valid ? () => close(log: true) : null,
        ),
        AppCtaButton(
          label: l10n.addMealAddToPlate,
          variant: AppCtaVariant.secondary,
          onPressed: valid ? () => close(log: false) : null,
        ),
      ],
    );
  }
}

class ItemAmountSheet extends StatelessWidget {
  const new({required this.item, super.key});

  final MealItemModel item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final amount = context.watch<AmountCubit>().state.amount;
    final perUnit = unitNutrients(item).values;
    double scaled(NutrientKey key) => (perUnit[key] ?? 0) * amount;
    return _SheetBody(
      title: item.displayName,
      field: _AmountField(unit: Text(item.unit)),
      macros: (
        calories: scaled(NutrientKey.calories),
        protein: scaled(NutrientKey.protein),
        carbs: scaled(NutrientKey.carbs),
        fat: scaled(NutrientKey.fatTotal),
      ),
      buttons: [
        AppCtaButton(
          label: l10n.addMealSaveAmount,
          onPressed: () => Navigator.of(context)
              .pop(editedItem(item, context.read<AmountCubit>().state.amount)),
        ),
      ],
    );
  }
}

/// A sheet's layout: the food, the amount, its macros and the buttons, above
/// the keyboard.
class _SheetBody extends StatelessWidget {
  const new({
    required this.title,
    required this.field,
    required this.macros,
    required this.buttons,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget field;
  final ({double? calories, double? protein, double? carbs, double? fat})
  macros;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    String grams(double? value) =>
        value == null ? AppFormat.placeholder : AppFormat.grams(value);
    final subtitle = this.subtitle;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.m,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.sectionTitle,
                    semanticsLabel: title,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: AppTextStyles.rowDetail.copyWith(color: secondary),
                    ),
                  field,
                  Text(
                    l10n.addMealEstimatedMacros,
                    style: AppTextStyles.label.copyWith(color: secondary),
                  ),
                  Wrap(
                    spacing: AppSpacing.xl,
                    runSpacing: AppSpacing.s,
                    children: [
                      AppStat(
                        value: macros.calories == null
                            ? AppFormat.placeholder
                            : AppFormat.kcal(macros.calories!.round()),
                        label: l10n.nutritionMacroCalories,
                        size: AppStatSize.small,
                      ),
                      AppStat(
                        value: grams(macros.protein),
                        label: l10n.nutritionMacroProtein,
                        size: AppStatSize.small,
                      ),
                      AppStat(
                        value: grams(macros.carbs),
                        label: l10n.nutritionMacroCarbs,
                        size: AppStatSize.small,
                      ),
                      AppStat(
                        value: grams(macros.fat),
                        label: l10n.nutritionMacroFat,
                        size: AppStatSize.small,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AppBottomCta(children: buttons),
          ],
        ),
      ),
    );
  }
}

/// The amount, focused with its text selected so typing replaces it, and
/// its unit.
class _AmountField extends StatefulWidget {
  const new({required this.unit});

  final Widget unit;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final _controller = TextEditingController(
    text: context.read<AmountCubit>().state.text,
  );

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AmountCubit, AmountState>(
      // A unit change rewrites the amount; typing does not come back here.
      listenWhen: (previous, current) => current.text != _controller.text,
      listener: (_, state) => _controller.text = state.text,
      child: Row(
        spacing: AppSpacing.m,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: context.l10n.addMealAmount,
              ),
              style: AppTextStyles.metric,
              onChanged: context.read<AmountCubit>().textChanged,
            ),
          ),
          widget.unit,
        ],
      ),
    );
  }
}
