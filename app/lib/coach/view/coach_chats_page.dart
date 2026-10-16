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
import 'package:compound/training_library/view/library_widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.coachWithdrawTitle),
        content: Text(l10n.coachWithdrawMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.coachCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.coachWithdrawConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await _cubit.withdrawConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<CoachChatsCubit>().state;
    final chats = state.chats;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;
    return BlocListener<CoachChatsCubit, CoachChatsState>(
      listenWhen: (previous, current) => current.noticeId != previous.noticeId,
      listener: (context, state) => switch (state.notice) {
        CoachChatsNotice.withdrawn => unawaited(
          HapticFeedback.successNotification(),
        ),
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
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.coachChatsTitle),
          actions: [
            IconButton(
              icon: const Icon(AppSymbols.add),
              tooltip: l10n.coachNewChat,
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
            ? const Center(child: CircularProgressIndicator.adaptive())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.l),
                children: [
                  if (chats.isEmpty)
                    LibraryEmptyState(
                      icon: AppSymbols.coach,
                      title: l10n.coachChatsEmptyTitle,
                      message: l10n.coachChatsEmptyMessage,
                    )
                  else
                    AppSection(
                      children: [
                        for (final chat in chats)
                          Dismissible(
                            key: ValueKey(chat.id),
                            direction: DismissDirection.endToStart,
                            background: ColoredBox(
                              color: scheme.error,
                              child: Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.l,
                                  ),
                                  child: Icon(
                                    AppSymbols.delete,
                                    color: scheme.onError,
                                  ),
                                ),
                              ),
                            ),
                            confirmDismiss: (_) async {
                              unawaited(_cubit.deleteChat(chat));
                              return false;
                            },
                            child: Semantics(
                              customSemanticsActions: {
                                CustomSemanticsAction(
                                  label: l10n.coachDelete,
                                ): () =>
                                    unawaited(_cubit.deleteChat(chat)),
                              },
                              child: AppListRowButton(
                                key: Key('CoachChats.${chat.id}'),
                                title: chat.title,
                                subtitle: DateFormat.yMMMd(locale)
                                    .add_jm()
                                    .format(chat.updatedAt.toLocal()),
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
                          tint: scheme.error,
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
