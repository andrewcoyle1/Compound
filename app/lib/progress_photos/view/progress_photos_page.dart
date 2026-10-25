import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/progress_photos/cubit/progress_photos_cubit.dart';
import 'package:compound/progress_photos/view/progress_photo_compare_page.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_repository/image_repository.dart';
import 'package:user_repository/user_repository.dart' show WeightUnitPreference;

/// Progress Photos (Swift `ProgressPhotosView`), under Body Metrics.
class ProgressPhotosPage extends StatelessWidget {
  const new({super.key});

  /// Under Body Metrics: `/progress/body-metrics/photos`.
  static const path = 'photos';
  static const name = 'progressPhotos';

  @override
  Widget build(BuildContext context) {
    // The router only shows the tabs while someone is signed in.
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => ProgressPhotosCubit(
        uid: app.user.uid,
        body: context.read<BodyRepository>(),
        images: context.read<ImageRepository>(),
        picker: context.read<PhotoPicker>(),
        analytics: context.read<AnalyticsRepository>(),
        weightUnit:
            app.profile?.submittedWeightUnitPreference ==
                WeightUnitPreference.pounds
            ? AppWeightUnit.pounds
            : AppWeightUnit.kilograms,
      ),
      child: const ProgressPhotosView(),
    );
  }
}

/// A pose's name.
String poseTitle(AppLocalizations l10n, ProgressPhotoPose pose) =>
    switch (pose) {
      ProgressPhotoPose.front => l10n.progressPhotoPoseFront,
      ProgressPhotoPose.side => l10n.progressPhotoPoseSide,
      ProgressPhotoPose.back => l10n.progressPhotoPoseBack,
    };

/// A photo's date, and its weight when it has one
/// (`ProgressPhotosPresenter.caption`).
String photoCaption(
  BuildContext context,
  ProgressPhotoModel photo,
  AppWeightUnit unit,
) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final date = AppFormat.date(photo.date.toLocal(), locale: context.dateLocale);
  final weightKg = photo.weightKg;
  if (weightKg == null) return date;
  return context.l10n.progressPhotoCaption(
    date,
    AppFormat.weight(weightKg, unit, locale: locale),
  );
}

class ProgressPhotosView extends StatelessWidget {
  const new({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    ProgressPhotoModel photo,
  ) async {
    final l10n = context.l10n;
    final cubit = context.read<ProgressPhotosCubit>();
    final confirmed = await AppDialog.confirmDestructive(
      context,
      title: l10n.progressPhotosDeleteQuestion,
      confirmLabel: l10n.progressPhotosDelete,
    );
    if (confirmed) await cubit.deleteConfirmed(photo);
  }

  Future<void> _askPose(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<ProgressPhotosCubit>();
    final pose = await showAppDialog<ProgressPhotoPose>(
      context: context,
      title: l10n.progressPhotosPoseQuestion,
      actions: [
        for (final pose in ProgressPhotoPose.values)
          AppDialogAction(label: poseTitle(l10n, pose), value: pose),
        AppDialogAction(
          label: l10n.progressPhotosCancel,
          role: AppDialogRole.cancel,
        ),
      ],
    );
    if (pose == null) {
      cubit.poseCancelled();
    } else {
      await cubit.poseSelected(pose);
    }
  }

  void _alert(BuildContext context, String title) => unawaited(
    showAppDialog<void>(
      context: context,
      title: title,
      message: context.l10n.progressPhotosFailedMessage,
      actions: [AppDialogAction(label: context.l10n.settingsOk)],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ProgressPhotosCubit>();
    final state = context.watch<ProgressPhotosCubit>().state;
    final selected = state.selectedForDelete;
    final pair = state.comparePair;
    void compare((ProgressPhotoModel, ProgressPhotoModel) pair) {
      cubit.comparePressed();
      unawaited(
        context.pushNamed(
          ProgressPhotoComparePage.name,
          extra: ProgressPhotoComparison(
            before: pair.$1,
            after: pair.$2,
            beforeCaption: photoCaption(context, pair.$1, state.weightUnit),
            afterCaption: photoCaption(context, pair.$2, state.weightUnit),
          ),
        ),
      );
    }

    return MultiBlocListener(
      listeners: [
        BlocListener<ProgressPhotosCubit, ProgressPhotosState>(
          listenWhen: (previous, current) =>
              previous.pendingImage == null && current.pendingImage != null,
          listener: (context, _) => unawaited(_askPose(context)),
        ),
        BlocListener<ProgressPhotosCubit, ProgressPhotosState>(
          listenWhen: (previous, current) =>
              previous.addFailures != current.addFailures,
          listener: (context, _) =>
              _alert(context, l10n.progressPhotosAddFailed),
        ),
        BlocListener<ProgressPhotosCubit, ProgressPhotosState>(
          listenWhen: (previous, current) =>
              previous.deleteFailures != current.deleteFailures,
          listener: (context, _) =>
              _alert(context, l10n.progressPhotosDeleteFailed),
        ),
        BlocListener<ProgressPhotosCubit, ProgressPhotosState>(
          listenWhen: (previous, current) =>
              previous.loadFailures != current.loadFailures,
          listener: (context, _) =>
              _alert(context, l10n.progressPhotosLoadFailed),
        ),
      ],
      child: AppScaffold(
        appBar: AppBar(
          title: Text(l10n.progressPhotosTitle),
          actions: [
            AppToolbarButton(
              icon: AppSymbols.delete,
              semanticLabel: l10n.progressPhotosDelete,
              onPressed: selected == null
                  ? null
                  : () => unawaited(_confirmDelete(context, selected)),
            ),
            _AddPhotoMenu(enabled: !state.isUploading),
          ],
        ),
        // Compare is the screen's one action, once there are photos to
        // compare: two picked.
        bottomNavigationBar: AppBottomCta(
          children: [
            if (state.loaded && state.photos.isNotEmpty)
              AppCtaButton(
                label: l10n.progressPhotosCompare,
                onPressed: pair == null ? null : () => compare(pair),
              ),
          ],
        ),
        body: Stack(
          children: [
            if (!state.loaded)
              AppLoadingView(label: l10n.launchLoading)
            else if (state.photos.isEmpty)
              _Empty(enabled: !state.isUploading)
            else
              _Photos(
                state: state,
                onDelete: (photo) => unawaited(_confirmDelete(context, photo)),
              ),
            if (state.isUploading)
              Center(
                child: AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.s,
                      children: [
                        const AppSpinner(),
                        Text(l10n.progressPhotosUploading),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The + menu: a camera item per pose, so the pose is known before the
/// shutter, and the library, which asks the pose afterwards.
class _AddPhotoMenu extends StatelessWidget {
  const new({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MenuAnchor(
      menuChildren: [
        for (final (label, icon, action) in _addChoices(context))
          MenuItemButton(
            leadingIcon: Icon(icon),
            onPressed: () => unawaited(action()),
            child: Text(label),
          ),
      ],
      builder: (context, controller, _) => AppToolbarButton(
        icon: AppSymbols.add,
        semanticLabel: l10n.progressPhotosAdd,
        onPressed: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
      ),
    );
  }
}

/// What the + menu offers: its label, glyph and action.
List<(String, IconData, Future<void> Function())> _addChoices(
  BuildContext context,
) {
  final l10n = context.l10n;
  final cubit = context.read<ProgressPhotosCubit>();
  return [
    (
      l10n.progressPhotosTakeFront,
      AppSymbols.camera,
      () => cubit.cameraPressed(ProgressPhotoPose.front),
    ),
    (
      l10n.progressPhotosTakeSide,
      AppSymbols.camera,
      () => cubit.cameraPressed(ProgressPhotoPose.side),
    ),
    (
      l10n.progressPhotosTakeBack,
      AppSymbols.camera,
      () => cubit.cameraPressed(ProgressPhotoPose.back),
    ),
    (
      l10n.progressPhotosChooseFromLibrary,
      AppSymbols.photoLibrary,
      cubit.libraryPressed,
    ),
  ];
}

/// No photos yet: the same choices as the + menu, as a choice dialog, so it
/// is not a dead end.
class _Empty extends StatelessWidget {
  const new({required this.enabled});

  final bool enabled;

  Future<void> _choose(BuildContext context) async {
    final l10n = context.l10n;
    final choices = _addChoices(context);
    final chosen = await showAppDialog<int>(
      context: context,
      title: l10n.progressPhotosAdd,
      actions: [
        for (final (index, (label, _, _)) in choices.indexed)
          AppDialogAction(label: label, value: index),
        AppDialogAction(
          label: l10n.progressPhotosCancel,
          role: AppDialogRole.cancel,
        ),
      ],
    );
    if (chosen != null) await choices[chosen].$3();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppEmptyState(
      icon: AppSymbols.camera,
      title: l10n.progressPhotosEmptyTitle,
      description: l10n.progressPhotosEmptyMessage,
      // Hidden while a photo uploads.
      actionLabel: enabled ? l10n.progressPhotosAdd : null,
      onAction: enabled ? () => unawaited(_choose(context)) : null,
    );
  }
}

class _Photos extends StatelessWidget {
  const new({required this.state, required this.onDelete});

  final ProgressPhotosState state;
  final ValueChanged<ProgressPhotoModel> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppContentWidth.readable),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              Text(
                l10n.progressPhotosSelectHint,
                style: AppTextStyles.rowDetail.secondary(context),
              ),
              for (final (day, photos) in state.sections) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppFormat.date(
                    day,
                    style: AppDateStyle.full,
                    locale: context.dateLocale,
                  ),
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: AppSpacing.s),
                GridView.extent(
                  maxCrossAxisExtent: 160,
                  childAspectRatio: 3 / 4,
                  mainAxisSpacing: AppSpacing.s,
                  crossAxisSpacing: AppSpacing.s,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final photo in photos)
                      _PhotoCell(
                        photo: photo,
                        caption: photoCaption(context, photo, state.weightUnit),
                        isSelected: state.isSelected(photo),
                        onDelete: () => onDelete(photo),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const new({
    required this.photo,
    required this.caption,
    required this.isSelected,
    required this.onDelete,
  });

  final ProgressPhotoModel photo;
  final String caption;
  final bool isSelected;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final pose = poseTitle(l10n, photo.pose);
    final url = photo.imageUrl;
    return Semantics(
      label: l10n.progressPhotoLabel(pose, caption),
      button: true,
      selected: isSelected,
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.progressPhotosDelete): onDelete,
      },
      excludeSemantics: true,
      child: AppPressable(
        onTap: () => context.read<ProgressPhotosCubit>().photoPressed(photo),
        // Swift's context menu; the toolbar's Delete does the same for one
        // chosen photo.
        onLongPress: onDelete,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.m),
          child: AppSelectionRing(
            selected: isSelected,
            radius: AppRadius.m,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: scheme.surfaceContainerHighest),
                if (url != null) StoredImage(url),
                Positioned(
                  left: AppSpacing.s,
                  bottom: AppSpacing.s,
                  child: AppChip(label: pose),
                ),
                if (isSelected)
                  Positioned(
                    top: AppSpacing.s,
                    right: AppSpacing.s,
                    child: Icon(
                      AppSymbols.choiceSelected,
                      color: scheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
