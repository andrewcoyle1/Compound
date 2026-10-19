import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/app/app.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/view/program_widgets.dart';
import 'package:compound/sharing/cubit/shared_item_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:program_repository/program_repository.dart';
import 'package:social_repository/social_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

/// What opens a shared item: the share, when the caller has it, and who
/// sent it.
final class const SharedItemRequest({
  required final ShareModel share,
  required final String senderName,
});

/// A shared template or mesocycle, read-only, with Add to Library and
/// Decline (`SharedItemView`).
class SharedItemPage extends StatelessWidget {
  const new({required this.shareId, this.request, super.key});

  /// The route's path, over the tabs.
  static const path = '/shares/:$idParameter';

  /// The route's name.
  static const name = 'sharedItem';

  /// The path parameter naming the share.
  static const idParameter = 'shareId';

  final String shareId;
  final SharedItemRequest? request;

  /// Opens [request]'s share.
  static Future<void> open(BuildContext context, SharedItemRequest request) =>
      context.pushNamed(
        name,
        pathParameters: {idParameter: request.share.id},
        extra: request,
      );

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppBloc>().state;
    if (app is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) {
        final cubit = SharedItemCubit(
          social: context.read<SocialRepository>(),
          library: context.read<TrainingLibraryRepository>(),
          programs: context.read<ProgramRepository>(),
          analytics: context.read<AnalyticsRepository>(),
          uid: app.user.uid,
          shareId: shareId,
          share: request?.share,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: SharedItemView(senderName: request?.senderName),
    );
  }
}

class SharedItemView extends StatefulWidget {
  const new({required this.senderName, super.key});

  /// Who sent it; unknown when opened by id alone.
  final String? senderName;

  @override
  State<SharedItemView> createState() => _SharedItemViewState();
}

class _SharedItemViewState extends State<SharedItemView> {
  late final SharedItemCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    super.dispose();
  }

  void _onChange(BuildContext context, SharedItemState state) {
    if (state.answered) {
      if (state.status == ShareStatus.accepted) {
        unawaited(AppHaptics.success());
      }
      context.pop();
      return;
    }
    final notice = state.notice;
    if (notice == null) return;
    final l10n = context.l10n;
    if (notice == SharedItemNotice.addFailed) {
      unawaited(AppHaptics.error());
    }
    final title = switch (notice) {
      SharedItemNotice.addFailed => l10n.sharedItemAddFailed,
      SharedItemNotice.declineFailed => l10n.sharedItemDeclineFailed,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$title. ${l10n.socialTryAgain}')));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<SharedItemCubit>().state;
    final share = state.share;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final senderName = widget.senderName;
    return BlocListener<SharedItemCubit, SharedItemState>(
      listenWhen: (previous, current) =>
          current.answered != previous.answered ||
          current.noticeId != previous.noticeId,
      listener: _onChange,
      child: AppScaffold(
        appBar: AppBar(
          title: Text(switch (share?.payload) {
            TemplateSharePayload(:final template) => template.name,
            MesocycleSharePayload(:final mesocycle) => mesocycle.name,
            null => '',
          }),
        ),
        body: switch ((share, state.notFound)) {
          (_, true) => AppErrorState(
            icon: AppSymbols.template,
            title: l10n.sharedItemNotFound,
          ),
          (null, _) => AppLoadingView(label: l10n.launchLoading),
          (final ShareModel share, _) => ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              if (senderName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.l),
                  child: Text(
                    l10n.sharedItemSharedBy(senderName),
                    style: AppTextStyles.rowDetail.copyWith(color: secondary),
                  ),
                ),
              if (share.payload case MesocycleSharePayload(:final mesocycle))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  child: AppSection(
                    children: [MesocycleHeader(mesocycle: mesocycle)],
                  ),
                ),
              for (final template in state.templates) ...[
                AppSection(
                  header: template.name,
                  children: [
                    for (final item in template.exercises)
                      AppListRow(
                        title: item.exercise.name,
                        accessory: AppListRowValue(
                          l10n.setCount(item.setTargets.length),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ],
          ),
        },
        bottomNavigationBar: share == null
            ? null
            : AppBottomCta(
                children: state.isAnswered
                    ? [
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.l),
                          child: Text(
                            state.status == ShareStatus.accepted
                                ? l10n.sharedItemAdded
                                : l10n.sharedItemDismissed,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.rowDetail.copyWith(
                              color: secondary,
                            ),
                          ),
                        ),
                      ]
                    : [
                        AppCtaButton(
                          label: l10n.sharedItemAddToLibrary,
                          isLoading: state.isWorking,
                          onPressed: state.isWorking
                              ? null
                              : _cubit.addToLibraryPressed,
                        ),
                        AppCtaButton(
                          label: l10n.sharedItemDecline,
                          variant: AppCtaVariant.plain,
                          onPressed: state.isWorking
                              ? null
                              : _cubit.declinePressed,
                        ),
                      ],
              ),
      ),
    );
  }
}
