import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/view/widgets/macro_header.dart';
import 'package:flutter/semantics.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// [time] as the device prints a time of day: `1:00 PM`, or `13:00` with
/// the 24-hour clock on.
String _formatTime(BuildContext context, DateTime time) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(time.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
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
    final style = AppTextStyles.label.copyWith(
      fontWeight: FontWeight.w600,
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
          IconButton(
            icon: const Icon(AppSymbols.add),
            tooltip: l10n.nutritionLogMealAt(_formatTime(context, hour)),
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
    final scheme = Theme.of(context).colorScheme;
    final onDelete = onDeleteItem;
    final onOpen = onOpenMeal;
    final onAgain = onLogAgain;
    if (onDelete == null && onOpen == null && onAgain == null) return child;
    Widget swipeBackground(
      Color color,
      Color onColor,
      IconData icon,
      AlignmentGeometry alignment,
    ) => ColoredBox(
      color: color,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Icon(icon, color: onColor),
        ),
      ),
    );
    final direction = switch ((onDelete != null, onAgain != null)) {
      (true, true) => DismissDirection.horizontal,
      (true, false) => DismissDirection.endToStart,
      (false, true) => DismissDirection.startToEnd,
      (false, false) => DismissDirection.none,
    };
    return Dismissible(
      key: ValueKey(item.itemId),
      direction: direction,
      background: swipeBackground(
        scheme.primary,
        scheme.onPrimary,
        AppSymbols.logAgain,
        AlignmentDirectional.centerStart,
      ),
      secondaryBackground: swipeBackground(
        scheme.error,
        scheme.onError,
        AppSymbols.delete,
        AlignmentDirectional.centerEnd,
      ),
      // Nothing slides away: a deleted food leaves when the meal log says
      // it has gone, and if the delete fails it stays.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onDelete?.call(item);
        } else {
          onAgain?.call();
        }
        return false;
      },
      // The same actions for anyone who cannot swipe.
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: l10n.nutritionViewMeal): ?onOpen,
          CustomSemanticsAction(label: l10n.nutritionLogMealAgain): ?onAgain,
          if (onDelete != null)
            CustomSemanticsAction(label: l10n.nutritionDeleteItem): () =>
                onDelete(item),
        },
        child: InkWell(
          onTap: onOpen,
          onLongPress: () => unawaited(_showMenu(context, item)),
          child: child,
        ),
      ),
    );
  }

  /// The long press's menu (Swift's `contextMenu`).
  Future<void> _showMenu(BuildContext context, MealItemModel item) async {
    final l10n = context.l10n;
    final onDelete = onDeleteItem;
    final action = await showModalBottomSheet<VoidCallback>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onOpenMeal case final open?)
              ListTile(
                leading: const Icon(AppSymbols.meal),
                title: Text(l10n.nutritionViewMeal),
                onTap: () => Navigator.of(context).pop(open),
              ),
            if (onLogAgain case final again?)
              ListTile(
                leading: const Icon(AppSymbols.logAgain),
                title: Text(l10n.nutritionLogMealAgain),
                onTap: () => Navigator.of(context).pop(again),
              ),
            if (onDelete != null)
              ListTile(
                leading: Icon(
                  AppSymbols.delete,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  l10n.nutritionDeleteItem,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.of(context).pop(() => onDelete(item)),
              ),
          ],
        ),
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
    final detail = [
      if (details && settings.showCaloriesInTimeline)
        AppFormat.kcal(macros.calories),
      if (details && settings.showMacrosInTimeline) ...[
        l10n.nutritionItemProtein(AppFormat.grams(macros.proteinGrams)),
        l10n.nutritionItemFat(AppFormat.grams(macros.fatGrams)),
        l10n.nutritionItemCarbs(AppFormat.grams(macros.carbGrams)),
      ],
      '${AppFormat.number(item.amount, maxFractionDigits: 2)} ${item.unit}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        spacing: AppSpacing.m,
        children: [
          if (details && settings.showFoodImageInTimeline)
            Icon(
              AppSymbols.meal,
              size: AppIconSize.medium.of(context),
              color: scheme.onSurfaceVariant,
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xxs,
              children: [
                Text(
                  item.displayName,
                  style: AppTextStyles.rowTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Wraps rather than truncating, so the figures always show.
                Text(
                  detail,
                  style: AppTextStyles.rowDetail.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit case final onEdit?)
            IconButton(
              icon: const Icon(AppSymbols.edit),
              tooltip: l10n.nutritionEditItem(item.displayName),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }
}
