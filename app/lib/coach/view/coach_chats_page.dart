import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/coach/cubit/coach_chats_cubit.dart';
import 'package:compound/coach/cubit/coach_cubit.dart';
import 'package:compound/coach/view/coach_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/widgets/relative_time.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The coach's saved chats and the permission behind them (Swift
/// `CoachChatsView`), from the coach's menu and from Settings.
class CoachChatsPage extends StatelessWidget {
  const new({this.coachContext = CoachContext.today, super.key});

  /// Pushed over whatever opened it.
  static const path = '/coach-chats';

  /// The route name.
  static const name = 'coachChats';

  /// What a chat opened from here is about, when the list was opened from
  /// the coach; a new chat starts about it too.
  final CoachContext coachContext;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppBloc>().state;
    if (state is! AppAuthenticated) return const SizedBox.shrink();
    return BlocProvider(
      create: (context) => CoachChatsCubit(
        uid: state.user.uid,
        coach: context.read<CoachRepository>(),
        analytics: context.read<AnalyticsRepository>(),
      )..started(),
      child: CoachChatsView(coachContext: coachContext),
    );
  }
}

class CoachChatsView extends StatefulWidget {
  const new({required this.coachContext, super.key});

  final CoachContext coachContext;

  @override
  State<CoachChatsView> createState() => _CoachChatsViewState();
}

class _CoachChatsViewState extends State<CoachChatsView> {
  late final CoachChatsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<CoachChatsCubit>()..appeared();
  }

  @override
  void dispose() {
    _cubit.disappeared();
    super.dispose();
  }

  void _open(CoachRequest request) =>
      unawaited(context.pushNamed<void>(CoachPage.name, extra: request));

  Future<void> _withdraw() async {
    final l10n = context.l10n;
    final confirmed = await AppDialog.confirmDestructive(
      context,
      title: l10n.coachWithdrawTitle,
      message: l10n.coachWithdrawMessage,
      confirmLabel: l10n.coachWithdrawConfirm,
      cancelLabel: l10n.coachCancel,
    );
    if (confirmed) await _cubit.withdrawConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CoachChatsCubit>().state;
    final chats = state.chats;
    return BlocListener<CoachChatsCubit, CoachChatsState>(
      listenWhen: (previous, current) => current.noticeId != previous.noticeId,
      listener: (context, state) => switch (state.notice) {
        CoachChatsNotice.withdrawn => unawaited(AppHaptics.success()),
        CoachChatsNotice.deleteFailed => unawaited(
          showFailureAlert(
            context,
            l10n.coachDeleteFailed,
            l10n.metricTryAgain,
          ),
        ),
        CoachChatsNotice.withdrawFailed => unawaited(
          showFailureAlert(
            context,
            l10n.coachWithdrawFailed,
            l10n.metricTryAgain,
          ),
        ),
        null => null,
      },
      child: AppScaffold(
        appBar: AppBar(
          title: Text(l10n.coachChatsTitle),
          actions: [
            AppToolbarButton(
              icon: AppSymbols.add,
              semanticLabel: l10n.coachNewChat,
              onPressed: () {
                _cubit.newChatPressed();
                _open(
                  CoachRequest(
                    context: widget.coachContext,
                    showsCloseButton: false,
                  ),
                );
              },
            ),
          ],
        ),
        body: chats == null
            ? AppLoadingView(label: l10n.launchLoading)
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.l),
                children: [
                  if (chats.isEmpty)
                    AppEmptyState(
                      icon: AppSymbols.coach,
                      title: l10n.coachChatsEmptyTitle,
                      description: l10n.coachChatsEmptyMessage,
                    )
                  else
                    AppSection(
                      children: [
                        for (final chat in chats)
                          AppSwipeActions(
                            trailing: [
                              AppSwipeAction(
                                label: l10n.coachDelete,
                                icon: AppSymbols.delete,
                                isDestructive: true,
                                onPressed: () =>
                                    unawaited(_cubit.deleteChat(chat)),
                              ),
                            ],
                            child: RelativeTimeBuilder(
                              date: chat.updatedAt,
                              builder: (context, updated) => AppListRowButton(
                                key: Key('CoachChats.${chat.id}'),
                                title: chat.title,
                                subtitle: updated,
                                icon: AppSymbols.coach,
                                onPressed: () {
                                  _cubit.chatPressed();
                                  _open(
                                    CoachRequest.forChat(
                                      chat,
                                      widget.coachContext,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  if (state.hasConsented) ...[
                    const SizedBox(height: AppSpacing.xl),
                    AppSection(
                      header: l10n.coachDataSharingHeader,
                      footer: l10n.coachDataSharingFooter,
                      children: [
                        AppListRowButton(
                          title: l10n.coachWithdraw,
                          destructive: true,
                          icon: AppSymbols.lock,
                          onPressed: state.isWithdrawing
                              ? null
                              : () => unawaited(_withdraw()),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
