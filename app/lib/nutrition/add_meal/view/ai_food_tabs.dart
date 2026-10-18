part of 'food_picker.dart';

// MARK: - AI estimates

/// An AI result's tap (`onResultTapped`): the amount sheet, prefilled with
/// the estimate's grams, whatever the Quick Add setting. The estimate is
/// not a library food, so it is not saved.
Future<void> _addEstimate(BuildContext context, FoodAnalysisItem item) async {
  final bloc = context.read<AddMealBloc>();
  final result = await showFoodAmountSheet(
    context,
    item.estimatedFood(now: DateTime.now()),
    amount: item.amountGrams,
  );
  if (result == null) return;
  unawaited(HapticFeedback.successNotification());
  bloc.add(AddMealItemAdded(result.item));
  if (result.log) bloc.add(const AddMealSaveRequested());
}

/// Add All: every estimate onto the plate as it is.
void _addAllEstimates(BuildContext context, List<FoodAnalysisItem> items) {
  final bloc = context.read<AddMealBloc>();
  unawaited(HapticFeedback.successNotification());
  for (final item in items) {
    bloc.add(AddMealItemAdded(item.mealItem()));
  }
}

/// The foods the AI found (Swift's results section with
/// `AIEstimateHeader` and `FoodAnalysisResultRow`): Add All in the header,
/// a row per food that opens its amount, and a warning that estimates can
/// be wrong.
class _EstimateSection extends StatelessWidget {
  const new({
    required this.items,
    required this.addedAll,
    required this.onAddAll,
    required this.onTap,
  });

  final List<FoodAnalysisItem> items;
  final bool addedAll;
  final VoidCallback onAddAll;
  final ValueChanged<FoodAnalysisItem> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.l),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.aiEstimateHeader,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: secondary,
                    ),
                  ),
                ),
              ),
              if (addedAll)
                TextButton.icon(
                  onPressed: null,
                  icon: const Icon(AppSymbols.selected),
                  label: Text(l10n.aiEstimateAdded),
                )
              else
                TextButton(
                  onPressed: onAddAll,
                  child: Text(l10n.aiEstimateAddAll(items.length)),
                ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            children: [
              for (final (index, item) in items.indexed) ...[
                if (index > 0) const Divider(indent: AppSpacing.l),
                _EstimateRow(item: item, onTap: () => onTap(item)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Text(
            l10n.aiEstimateFooter,
            style: AppTextStyles.label.copyWith(color: secondary),
          ),
        ),
      ],
    );
  }
}

class _EstimateRow extends StatelessWidget {
  const new({required this.item, required this.onTap});

  final FoodAnalysisItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    // Only what the model estimated; a missing figure is not a zero.
    final detail = [
      AppFormat.grams(item.amountGrams),
      if (item.calories case final kcal?) AppFormat.kcal(kcal.round()),
      if (item.proteinGrams case final grams?)
        l10n.nutritionItemProtein(AppFormat.grams(grams)),
      if (item.fatGrams case final grams?)
        l10n.nutritionItemFat(AppFormat.grams(grams)),
      if (item.carbGrams case final grams?)
        l10n.nutritionItemCarbs(AppFormat.grams(grams)),
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.l),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xxs,
                  children: [
                    Text(item.name, style: AppTextStyles.rowTitle),
                    Text(
                      detail,
                      style: AppTextStyles.rowDetail.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(AppSymbols.add),
              tooltip: l10n.aiEstimateAdd(item.name),
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// A spinner with what it is waiting for.
class _Working extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.l),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: AppSpacing.s,
      children: [
        const SizedBox.square(
          dimension: AppSpacing.l,
          child: CircularProgressIndicator.adaptive(),
        ),
        Flexible(child: Text(text)),
      ],
    ),
  );
}

// MARK: - AI photo

class _PhotoTab extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => FoodPhotoScannerCubit(
      ai: context.read<AiRepository>(),
      picker: context.read<PhotoPicker>(),
      analytics: context.read<AnalyticsRepository>(),
      connectivity: context.read(),
    ),
    child: const _PhotoView(),
  );
}

class _PhotoView extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<FoodPhotoScannerCubit>();
    final state = context.watch<FoodPhotoScannerCubit>().state;
    final photo = state.photo;
    return BlocListener<FoodPhotoScannerCubit, FoodPhotoScannerState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == EstimateStatus.failed,
      listener: (_, _) => unawaited(HapticFeedback.errorNotification()),
      child: photo == null
          ? SingleChildScrollView(
              child: switch (state.camera) {
                CameraState.denied => _Empty(
                  icon: AppSymbols.camera,
                  title: l10n.aiScanCameraOffTitle,
                  message: l10n.aiScanCameraOffMessage,
                  action: FilledButton(
                    onPressed: () => unawaited(cubit.openSettings()),
                    child: Text(l10n.aiScanOpenSettings),
                  ),
                ),
                CameraState.unavailable => _Empty(
                  icon: AppSymbols.camera,
                  title: l10n.aiScanCameraUnavailableTitle,
                  message: l10n.aiScanCameraUnavailableMessage,
                ),
                CameraState.ready => _Empty(
                  icon: AppSymbols.camera,
                  title: l10n.addMealModeAi,
                  message: l10n.aiScanDisclosure,
                  action: FilledButton.icon(
                    key: const Key('FoodPicker.takePhoto'),
                    icon: const Icon(AppSymbols.camera),
                    label: Text(l10n.aiScanTakePhoto),
                    onPressed: () => unawaited(cubit.takePhoto()),
                  ),
                ),
              },
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                    child: Image.memory(
                      photo,
                      height: AppChartHeight.regular,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(height: AppChartHeight.regular),
                    ),
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(AppSymbols.camera),
                    label: Text(l10n.aiScanRetake),
                    onPressed: () => unawaited(cubit.retake()),
                  ),
                ),
                switch (state.status) {
                  EstimateStatus.idle ||
                  EstimateStatus.analysing => _Working(l10n.aiScanAnalyzing),
                  EstimateStatus.failed || EstimateStatus.offline => Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: AppInlineMessage(
                      kind: AppInlineMessageKind.error,
                      text: state.status == EstimateStatus.offline
                          ? l10n.aiScanOffline
                          : l10n.aiScanFailed,
                      kindLabel: l10n.addMealErrorLabel,
                    ),
                  ),
                  EstimateStatus.analysed when state.items.isEmpty => _Empty(
                    icon: AppSymbols.food,
                    title: l10n.aiScanNoFoodsTitle,
                    message: l10n.aiScanNoFoodsMessage,
                  ),
                  EstimateStatus.analysed => _EstimateSection(
                    items: state.items,
                    addedAll: state.addedAll,
                    onAddAll: () {
                      cubit.addAll();
                      _addAllEstimates(context, state.items);
                    },
                    onTap: (item) {
                      cubit.resultTapped(item);
                      unawaited(_addEstimate(context, item));
                    },
                  ),
                },
              ],
            ),
    );
  }
}

// MARK: - Describe

class _DescribeTab extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => MealDescribeCubit(
      ai: context.read<AiRepository>(),
      analytics: context.read<AnalyticsRepository>(),
      connectivity: context.read(),
    ),
    child: const _DescribeView(),
  );
}

class _DescribeView extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<MealDescribeCubit>();
    final state = context.watch<MealDescribeCubit>().state;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return BlocListener<MealDescribeCubit, MealDescribeState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == EstimateStatus.failed,
      listener: (_, _) => unawaited(HapticFeedback.errorNotification()),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.m),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.describeHeader,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: secondary,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${AppFormat.number(state.text.characters.length)}/'
                  '${AppFormat.number(MealDescribeCubit.characterLimit)}',
                  style: AppTextStyles.label.copyWith(
                    color: secondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: TextField(
                key: const Key('FoodPicker.describeField'),
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    MealDescribeCubit.characterLimit,
                  ),
                ],
                decoration: InputDecoration(
                  hintText: l10n.describePrompt,
                  border: InputBorder.none,
                ),
                onChanged: cubit.textChanged,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Text(
              l10n.describeFooter,
              style: AppTextStyles.label.copyWith(color: secondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: AppCtaButton(
              label: l10n.describeAnalyze,
              isLoading: state.status == EstimateStatus.analysing,
              onPressed: state.canAnalyse
                  ? () {
                      FocusScope.of(context).unfocus();
                      unawaited(cubit.analyse());
                    }
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          switch (state.status) {
            // Offline, the alert says why; nothing was sent.
            EstimateStatus.idle ||
            EstimateStatus.analysing ||
            EstimateStatus.offline => const SizedBox.shrink(),
            EstimateStatus.failed => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: AppInlineMessage(
                kind: AppInlineMessageKind.error,
                text: l10n.describeFailed,
                kindLabel: l10n.addMealErrorLabel,
              ),
            ),
            EstimateStatus.analysed when state.items.isEmpty => _Empty(
              icon: AppSymbols.food,
              title: l10n.aiScanNoFoodsTitle,
              message: l10n.describeNoFoodsMessage,
            ),
            EstimateStatus.analysed => _EstimateSection(
              items: state.items,
              addedAll: state.addedAll,
              onAddAll: () {
                cubit.addAll();
                _addAllEstimates(context, state.items);
              },
              onTap: (item) {
                cubit.resultTapped(item);
                unawaited(_addEstimate(context, item));
              },
            ),
          },
        ],
      ),
    );
  }
}
