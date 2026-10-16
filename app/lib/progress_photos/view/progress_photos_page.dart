import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/view/program_widgets.dart'
    show confirmDestructive;
import 'package:compound/progress_photos/cubit/progress_photos_cubit.dart';
import 'package:compound/progress_photos/view/progress_photo_compare_page.dart';
import 'package:compound/widgets/stored_image.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_repository/image_repository.dart';
import 'package:intl/intl.dart';
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
  final date = DateFormat.yMMMd(locale).format(photo.date.toLocal());
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
    final confirmed = await confirmDestructive(
      context,
      title: l10n.progressPhotosDeleteQuestion,
      confirmLabel: l10n.progressPhotosDelete,
    );
    if (confirmed) await cubit.deleteConfirmed(photo);
  }

  Future<void> _askPose(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<ProgressPhotosCubit>();
    final pose = await showModalBottomSheet<ProgressPhotoPose>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.l),
              child: Text(
                l10n.progressPhotosPoseQuestion,
                style: AppTextStyles.sectionTitle,
              ),
            ),
            for (final pose in ProgressPhotoPose.values)
              ListTile(
                title: Text(poseTitle(l10n, pose)),
                onTap: () => Navigator.of(context).pop(pose),
              ),
            ListTile(
              title: Text(l10n.progressPhotosCancel),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
    if (pose == null) {
      cubit.poseCancelled();
    } else {
      await cubit.poseSelected(pose);
    }
  }

  void _alert(BuildContext context, String title) => showAdaptiveDialog<void>(
    context: context,
    builder: (context) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(context.l10n.progressPhotosFailedMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.settingsOk),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ProgressPhotosCubit>();
    final state = context.watch<ProgressPhotosCubit>().state;
    final selected = state.selectedForDelete;
    final pair = state.comparePair;
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.progressPhotosTitle),
          actions: [
            TextButton(
              onPressed: pair == null
                  ? null
                  : () {
                      cubit.comparePressed();
                      unawaited(
                        context.pushNamed(
                          ProgressPhotoComparePage.name,
                          extra: ProgressPhotoComparison(
                            before: pair.$1,
                            after: pair.$2,
                            beforeCaption: photoCaption(
                              context,
                              pair.$1,
                              state.weightUnit,
                            ),
                            afterCaption: photoCaption(
                              context,
                              pair.$2,
                              state.weightUnit,
                            ),
                          ),
                        ),
                      );
                    },
              child: Text(l10n.progressPhotosCompare),
            ),
            IconButton(
              icon: const Icon(AppSymbols.delete),
              tooltip: l10n.progressPhotosDelete,
              onPressed: selected == null
                  ? null
                  : () => unawaited(_confirmDelete(context, selected)),
            ),
            _AddPhotoMenu(
              enabled: !state.isUploading,
              child: const Icon(AppSymbols.add),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (!state.loaded)
              const Center(child: CircularProgressIndicator.adaptive())
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
                        const CircularProgressIndicator.adaptive(),
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
  const new({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ProgressPhotosCubit>();
    PopupMenuItem<void> item(
      String label,
      IconData icon,
      Future<void> Function() onTap,
    ) => PopupMenuItem(
      onTap: () => unawaited(onTap()),
      child: ListTile(leading: Icon(icon), title: Text(label)),
    );
    return PopupMenuButton<void>(
      tooltip: l10n.progressPhotosAdd,
      enabled: enabled,
      itemBuilder: (_) => [
        item(
          l10n.progressPhotosTakeFront,
          AppSymbols.camera,
          () => cubit.cameraPressed(ProgressPhotoPose.front),
        ),
        item(
          l10n.progressPhotosTakeSide,
          AppSymbols.camera,
          () => cubit.cameraPressed(ProgressPhotoPose.side),
        ),
        item(
          l10n.progressPhotosTakeBack,
          AppSymbols.camera,
          () => cubit.cameraPressed(ProgressPhotoPose.back),
        ),
        item(
          l10n.progressPhotosChooseFromLibrary,
          AppSymbols.photoLibrary,
          cubit.libraryPressed,
        ),
      ],
      child: Padding(padding: const EdgeInsets.all(AppSpacing.s), child: child),
    );
  }
}

/// No photos yet: the same choices as the + menu, so it is not a dead end.
class _Empty extends StatelessWidget {
  const new({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s,
          children: [
            Icon(
              AppSymbols.camera,
              size: AppIconSize.hero.of(context),
              color: secondary,
            ),
            Text(
              l10n.progressPhotosEmptyTitle,
              style: AppTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
            Text(
              l10n.progressPhotosEmptyMessage,
              style: AppTextStyles.rowDetail.copyWith(color: secondary),
              textAlign: TextAlign.center,
            ),
            _AddPhotoMenu(
              enabled: enabled,
              child: Text(
                l10n.progressPhotosAdd,
                style: AppTextStyles.rowTitle.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
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
    final locale = Localizations.localeOf(context).toLanguageTag();
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
                style: AppTextStyles.rowDetail.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              for (final (day, photos) in state.sections) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  DateFormat.yMMMMEEEEd(locale).format(day),
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
      child: GestureDetector(
        onTap: () => context.read<ProgressPhotosCubit>().photoPressed(photo),
        // Swift's context menu; the toolbar's Delete does the same for one
        // chosen photo.
        onLongPress: onDelete,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.m),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: isSelected
                  ? Border.all(color: scheme.primary, width: 3)
                  : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: scheme.surfaceContainerHighest),
                if (url != null) StoredImage(url),
                Positioned(
                  left: AppSpacing.s,
                  bottom: AppSpacing.s,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: const StadiumBorder(),
                      color: scheme.surface.withValues(alpha: 0.8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s,
                        vertical: AppSpacing.xxs,
                      ),
                      child: Text(
                        pose,
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
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
