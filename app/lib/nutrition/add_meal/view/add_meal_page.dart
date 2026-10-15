import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/app/document_id.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/nutrition/add_meal/bloc/add_meal_bloc.dart';
import 'package:compound/nutrition/add_meal/view/amount_sheets.dart';
import 'package:compound/nutrition/add_meal/view/food_picker.dart';
import 'package:compound/nutrition/cubit/meal_draft_cubit.dart';
import 'package:compound/nutrition/logic/meal_day.dart';
import 'package:compound/nutrition/logic/meal_logging.dart';
import 'package:compound/nutrition/view/widgets/macro_header.dart';
import 'package:compound/shell/app_tab.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_repository/food_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrition_repository/nutrition_repository.dart';

/// Opens the logger for a meal eaten at [date] (Swift
/// `NutritionPresenter.onLogMealPressed` and `MealHourHeaderPresenter
/// .onAddMealPressed`). With an unlogged meal waiting, asks first whether to
/// carry on with it or start again.
Future<void> openMealLogger(
  BuildContext context, {
  required DateTime date,
}) async {
  final app = context.read<AppBloc>().state;
  if (app is! AppAuthenticated) return;
  final drafts = context.read<MealDraftCubit>();
  final fresh = newMeal(uid: app.user.uid, date: date, mealId: newDocumentId());
  final draft = drafts.state;
  if (draft == null) return await AddMealPage.show(context, fresh);
  final l10n = context.l10n;
  final choice = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Text(
              l10n.addMealDraftTitle,
              style: AppTextStyles.sectionTitle,
            ),
          ),
          ListTile(
            title: Text(l10n.addMealDraftContinue),
            onTap: () => Navigator.of(context).pop(true),
          ),
          ListTile(
            title: Text(
              l10n.addMealDraftDiscard,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (!choice) drafts.clear();
  return await AddMealPage.show(context, choice ? draft : fresh);
}

/// Logging a meal (Swift `AddMealView`): the plate, with the food picker
/// over it until something is on it. Opened over the tabs with the meal to
/// build; opened directly (a screenshot hook) it starts a meal now.
class AddMealPage extends StatelessWidget {
  const new({this.meal, super.key});

  static const path = '/log-meal';
  static const name = 'logMeal';

  /// Opens the logger on [meal].
  static Future<void> show(BuildContext context, MealLogModel meal) =>
      context.pushNamed<void>(name, extra: meal);

  final MealLogModel? meal;

  @override
  Widget build(BuildContext context) {
    // The router only shows this page while someone is signed in.
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => AddMealBloc(
        nutritionRepository: context.read<NutritionRepository>(),
        foodRepository: context.read<FoodRepository>(),
        analyticsRepository: context.read<AnalyticsRepository>(),
        meal:
            meal ??
            newMeal(
              uid: state.user.uid,
              date: DateTime.now(),
              mealId: newDocumentId(),
            ),
      )..add(const AddMealSubscriptionRequested()),
      child: const AddMealView(),
    );
  }
}

class AddMealView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final pickerOpen = context.select<AddMealBloc, bool>(
      (bloc) => bloc.state.pickerOpen,
    );
    return MultiBlocListener(
      listeners: [
        // The plate is kept as a draft as it changes, so closing the logger
        // loses nothing (`AddMealPresenter.mealLog.didSet`).
        BlocListener<AddMealBloc, AddMealState>(
          listenWhen: (previous, current) =>
              previous.meal != current.meal && current.meal.items.isNotEmpty,
          listener: (context, state) =>
              context.read<MealDraftCubit>().keep(state.meal),
        ),
        BlocListener<AddMealBloc, AddMealState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            switch (state.status) {
              case AddMealStatus.saved:
                unawaited(HapticFeedback.successNotification());
                context.read<MealDraftCubit>().clear();
                _dismiss(context);
              case AddMealStatus.discarded:
                context.read<MealDraftCubit>().clear();
                _dismiss(context);
              case AddMealStatus.failure:
                unawaited(HapticFeedback.errorNotification());
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.l10n.addMealSaveFailedTitle),
                    content: Text(context.l10n.addMealSaveFailedMessage),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          MaterialLocalizations.of(context).okButtonLabel,
                        ),
                      ),
                    ],
                  ),
                );
              case AddMealStatus.editing || AddMealStatus.saving:
                break;
            }
          },
        ),
      ],
      // Back from the picker returns to the plate rather than leaving.
      child: PopScope(
        canPop: !pickerOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            context.read<AddMealBloc>().add(const AddMealPickerClosed());
          }
        },
        child: pickerOpen ? const FoodPickerView() : const _PlateView(),
      ),
    );
  }
}

/// Back to wherever the logger was opened from; to Nutrition when opened
/// directly.
void _dismiss(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppTab.nutrition.path);
  }
}

/// The plate (Swift `AddMealView`'s list): its totals against the day's
/// target, its items, and Add Food.
class _PlateView extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<AddMealBloc>();
    final state = context.watch<AddMealBloc>().state;
    final meal = state.meal;
    final time = TimeOfDay.fromDateTime(meal.date.toLocal());
    return Scaffold(
      appBar: AppBar(
        // Closing keeps the plate as a draft.
        leading: CloseButton(onPressed: () => _dismiss(context)),
        title: Text(l10n.addMealTitle),
        actions: [
          TextButton.icon(
            icon: const Icon(AppSymbols.duration),
            label: Text(
              MaterialLocalizations.of(context).formatTimeOfDay(
                time,
                alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                  context,
                ),
              ),
            ),
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
                helpText: l10n.addMealTimeTitle,
              );
              if (picked == null) return;
              final day = meal.date.toLocal();
              bloc.add(
                AddMealTimeChanged(
                  DateTime(
                    day.year,
                    day.month,
                    day.day,
                    picked.hour,
                    picked.minute,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: SegmentedButton<NutritionScope>(
              segments: [
                ButtonSegment(
                  value: NutritionScope.plate,
                  label: Text(l10n.addMealScopePlate),
                ),
                ButtonSegment(
                  value: NutritionScope.day,
                  label: Text(l10n.addMealScopeDay),
                ),
              ],
              selected: {state.scope},
              onSelectionChanged: (selection) {
                unawaited(HapticFeedback.selectionClick());
                bloc.add(AddMealScopeChanged(selection.single));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.s,
              children: [
                for (final macro in Macro.values)
                  AppStat(
                    // Whole numbers, cut rather than rounded, as Swift's
                    // `Int(_:)`.
                    value: l10n.nutritionMacroConsumed(
                      AppFormat.number(macro.of(state.totals).truncate()),
                      AppFormat.number(macro.of(state.target).truncate()),
                    ),
                    label: macro.label(l10n),
                    size: AppStatSize.small,
                  ),
              ],
            ),
          ),
          AppSection(
            header: l10n.addMealPlate,
            children: [
              if (meal.items.isEmpty) AppListRow(title: l10n.addMealPlateEmpty),
              for (final item in meal.items) _PlateItem(item: item),
              AppListRowButton(
                title: l10n.addMealAddFood,
                icon: AppSymbols.add,
                accessory: null,
                onPressed: () => bloc.add(const AddMealPickerOpened()),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: AppBottomCta(
        children: [
          AppCtaButton(
            label: l10n.addMealLog,
            isLoading: state.status == AddMealStatus.saving,
            onPressed: meal.items.isEmpty
                ? null
                : () => bloc.add(const AddMealSaveRequested()),
          ),
        ],
      ),
    );
  }
}

/// A plate item: tap to correct its amount, swipe to take it off.
class _PlateItem extends StatelessWidget {
  const new({required this.item});

  final MealItemModel item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<AddMealBloc>();
    final macros = item.macros;
    return Dismissible(
      key: ValueKey(item.itemId),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: Theme.of(context).colorScheme.error,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: Icon(
              AppSymbols.delete,
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
        ),
      ),
      onDismissed: (_) => bloc.add(AddMealItemRemoved(item.itemId)),
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: l10n.addMealRemoveItem): () =>
              bloc.add(AddMealItemRemoved(item.itemId)),
        },
        child: AppListRowButton(
          title: item.displayName,
          subtitle: [
            AppFormat.kcal(macros.calories.round()),
            [
              AppFormat.number(item.amount, maxFractionDigits: 2),
              item.unit,
            ].join(' '),
          ].join(' · '),
          onPressed: () async {
            final edited = await showItemAmountSheet(context, item);
            if (edited == null) return;
            unawaited(HapticFeedback.successNotification());
            bloc.add(AddMealItemChanged(edited));
          },
        ),
      ),
    );
  }
}
