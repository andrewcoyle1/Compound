import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/view/widgets/macro_header.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// [time] as the device prints a time of day: `1:00 PM`, or `13:00` with
/// the 24-hour clock on.
String _formatTime(BuildContext context, DateTime time) => AppFormat.time(
  time.toLocal(),
  use24HourFormat: context.use24HourFormat,
  locale: context.dateLocale,
);

/// [child] as wide as the widest time of day, so every hour's capsule and
/// every timestamp gutter is the same width in 12- and 24-hour locales.
class _TimeWidth extends StatelessWidget {
  const new({required this.child, required this.style});

  final Widget child;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: AlignmentDirectional.centerStart,
    children: [
      ExcludeSemantics(
        child: Visibility.maintain(
          visible: false,
          child: Text(
            _formatTime(context, DateTime(2000, 1, 1, 22)),
            style: style,
          ),
        ),
      ),
      child,
    ],
  );
}

/// One hour of the timeline (Swift `MealHourHeaderView`): its time, and the
/// totals of the meals eaten in it when the settings ask for them.
class MealHourHeader extends StatelessWidget {
  const new({
    required this.hour,
    required this.meals,
    required this.showTotals,
    this.onAdd,
    super.key,
  });

  /// The hour's start.
  final DateTime hour;

  /// The meals eaten in it.
  final List<MealLogModel> meals;

  /// Whether to show the hour's totals.
  final bool showTotals;

  /// The hour's +, which logs a meal at it; none when null (the Show Add
  /// Foods Button setting is off).
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final style = AppTextStyles.label.semibold.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: scheme.onSurfaceVariant,
    );
    final totals = totalsOf(meals);
    final onAdd = this.onAdd;
    return Row(
      spacing: AppSpacing.l,
      children: [
        DecoratedBox(
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: AppColors.tintedSurface(scheme.onSurfaceVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s,
              vertical: AppSpacing.xs,
            ),
            child: _TimeWidth(
              style: style,
              child: Text(_formatTime(context, hour), style: style),
            ),
          ),
        ),
        if (meals.isNotEmpty && showTotals)
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                spacing: AppSpacing.l,
                children: [
                  for (final macro in Macro.values)
                    AppStat(
                      // Whole numbers, cut rather than rounded, as in Swift.
                      value: AppFormat.number(macro.of(totals).truncate()),
                      label: macro.label(l10n),
                      size: AppStatSize.small,
                      alignment: CrossAxisAlignment.center,
                    ),
                ],
              ),
            ),
          )
        else
          const Spacer(),
        if (onAdd != null)
          AppIconButton(
            icon: AppSymbols.add,
            semanticLabel: l10n.nutritionLogMealAt(_formatTime(context, hour)),
            onPressed: onAdd,
          ),
      ],
    );
  }
}

/// One meal's foods on a card, with the meal's time in the gutter beside
/// the first of them (Swift `MealItemRowView` and `MealItemLabel`). With
/// the callbacks set, as on the Nutrition tab: a tap opens the meal, the
/// pencil corrects the food's amount, a swipe from the end deletes the
/// food and one from the start logs the meal again, and a long press (or a
/// screen reader's actions) offers View Meal, Log Meal Again and Delete.
class MealCard extends StatelessWidget {
  const new({
    required this.meal,
    required this.settings,
    this.onDeleteItem,
    this.onOpenMeal,
    this.onEditItem,
    this.onLogAgain,
    super.key,
  });

  /// The meal.
  final MealLogModel meal;

  /// How the rows are drawn.
  final FoodLogSettings settings;

  /// Deletes a food.
  final ValueChanged<MealItemModel>? onDeleteItem;

  /// Opens the meal (`NutritionPresenter.onViewMealPressed`).
  final VoidCallback? onOpenMeal;

  /// Corrects a food's amount (`NutritionPresenter.onEditMealItem`).
  final ValueChanged<MealItemModel>? onEditItem;

  /// Logs the meal again now (`NutritionPresenter.onLogAgainPressed`).
  final VoidCallback? onLogAgain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = AppTextStyles.label.copyWith(color: scheme.onSurfaceVariant);
    final first = meal.items.isEmpty ? null : meal.items.first;
    final time = first == null ? null : itemTimestamp(first, meal);
    final gutter = settings.showsFoodTimestamps
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
            child: _TimeWidth(
              style: style,
              child: time == null
                  ? const SizedBox.shrink()
                  : Text(_formatTime(context, time), style: style),
            ),
          )
        : null;
    final left = settings.timestampSide == TimestampSide.left;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.m,
      children: [
        if (left) ?gutter,
        Expanded(
          child: AppCard(
            style: AppCardStyle.tile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, item) in meal.items.indexed) ...[
                  if (index > 0) const Divider(indent: AppSpacing.l),
                  _actionable(
                    context,
                    item,
                    _MealItemLabel(
                      item: item,
                      settings: settings,
                      onEdit: onEditItem == null
                          ? null
                          : () => onEditItem!(item),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!left) ?gutter,
      ],
    );
  }

  Widget _actionable(BuildContext context, MealItemModel item, Widget child) {
    final l10n = context.l10n;
    final onDelete = onDeleteItem;
    final onOpen = onOpenMeal;
    final onAgain = onLogAgain;
    if (onDelete == null && onOpen == null && onAgain == null) return child;
    // Swift's swipe actions, none on a full swipe, and the long press's
    // menu for anyone who cannot swipe; screen readers get them all.
    return AppSwipeActions(
      leading: [
        if (onAgain != null)
          AppSwipeAction(
            label: l10n.nutritionLogAgain,
            icon: AppSymbols.logAgain,
            tint: Theme.of(context).colorScheme.primary,
            onPressed: onAgain,
          ),
        if (onOpen != null)
          AppSwipeAction(
            label: l10n.nutritionMeal,
            icon: AppSymbols.meal,
            onPressed: onOpen,
          ),
      ],
      trailing: [
        if (onDelete != null)
          AppSwipeAction(
            label: l10n.nutritionDeleteItem,
            icon: AppSymbols.delete,
            isDestructive: true,
            onPressed: () => onDelete(item),
          ),
      ],
      leadingFullSwipe: false,
      trailingFullSwipe: false,
      child: InkWell(
        onTap: onOpen,
        onLongPress: () => unawaited(_showMenu(context, item)),
        child: child,
      ),
    );
  }

  /// The long press's menu (Swift's `contextMenu`).
  Future<void> _showMenu(BuildContext context, MealItemModel item) async {
    final l10n = context.l10n;
    final onDelete = onDeleteItem;
    final action = await showAppSheet<VoidCallback>(
      context: context,
      size: AppSheetSize.compact,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.l),
        children: [
          AppSection(
            children: [
              if (onOpenMeal case final open?)
                AppListRowButton(
                  icon: AppSymbols.meal,
                  title: l10n.nutritionViewMeal,
                  accessory: null,
                  onPressed: () => Navigator.of(context).pop(open),
                ),
              if (onLogAgain case final again?)
                AppListRowButton(
                  icon: AppSymbols.logAgain,
                  title: l10n.nutritionLogMealAgain,
                  accessory: null,
                  onPressed: () => Navigator.of(context).pop(again),
                ),
              if (onDelete != null)
                AppListRowButton(
                  icon: AppSymbols.delete,
                  title: l10n.nutritionDeleteItem,
                  accessory: null,
                  destructive: true,
                  onPressed: () =>
                      Navigator.of(context).pop(() => onDelete(item)),
                ),
            ],
          ),
        ],
      ),
    );
    action?.call();
  }
}

class _MealItemLabel extends StatelessWidget {
  const new({required this.item, required this.settings, this.onEdit});

  final MealItemModel item;
  final FoodLogSettings settings;

  /// The pencil; none when null.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    // Hide Food Details wins over the individual toggles.
    final details = !settings.hideFoodDetails;
    final macros = item.macros;
    final amount = AppFormat.number(item.amount, maxFractionDigits: 2);
    final detail = [
      if (details && settings.showCaloriesInTimeline)
        AppFormat.kcal(macros.calories),
      if (details && settings.showMacrosInTimeline) ...[
        l10n.nutritionItemProtein(AppFormat.grams(macros.proteinGrams)),
        l10n.nutritionItemFat(AppFormat.grams(macros.fatGrams)),
        l10n.nutritionItemCarbs(AppFormat.grams(macros.carbGrams)),
      ],
      // A no-break space, as AppFormat's units: "350 g" wraps as one.
      '$amount\u00a0${item.unit}',
    ].join(' · ');
    // At accessibility sizes the text takes the row's width: the picture
    // goes, and the pencil moves under the figures.
    final large =
        MediaQuery.textScalerOf(context).scale(1) >=
        AppListRow.accessibilityTextScale;
    final edit = onEdit == null
        ? null
        : AppIconButton(
            icon: AppSymbols.edit,
            semanticLabel: l10n.nutritionEditItem(item.displayName),
            onPressed: onEdit,
          );
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        spacing: AppSpacing.m,
        children: [
          // A stand-in for the food's picture (Swift's
          // `fork.knife.circle.fill`).
          if (details && settings.showFoodImageInTimeline && !large)
            const AppIconBadge(icon: AppSymbols.meal),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Text(
                  item.displayName,
                  style: AppTextStyles.rowTitle,
                  maxLines: large ? null : 1,
                  overflow: large ? null : TextOverflow.ellipsis,
                ),
                // Wraps rather than truncating, so the figures always show.
                Text(
                  detail,
                  style: AppTextStyles.rowDetail.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (large) ?edit,
              ],
            ),
          ),
          if (!large) ?edit,
        ],
      ),
    );
  }
}
