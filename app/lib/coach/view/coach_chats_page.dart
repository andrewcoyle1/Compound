import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:checkin_repository/checkin_repository.dart'
    show localDayKey, localMidnight;
import 'package:coach_repository/coach_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/coach/cubit/coach_chats_cubit.dart';
import 'package:compound/coach/cubit/coach_cubit.dart';
import 'package:compound/coach/view/coach_page.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The coach's days and the permission behind them (Swift
/// `CoachChatsView`), from the coach and from Settings: a section a day,
/// newest first, holding that day's chat and any chat from before day
/// chats begun on it.
class CoachChatsPage extends StatelessWidget {
  const new({this.coachContext = CoachContext.today, super.key});

  /// Pushed over whatever opened it.
  static const path = '/coach-chats';

  /// The route name.
  static const name = 'coachChats';

  /// What today's chat opened from here is about, when the list was opened
  /// from the coach.
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
        appBar: AppBar(title: Text(l10n.coachChatsTitle)),
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
                    for (final (day, chats) in _byDay(chats)) ...[
                      AppSection(
                        header: AppFormat.date(
                          localMidnight(day),
                          style: AppDateStyle.weekdayMedium,
                          locale: context.dateLocale,
                        ),
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
                              child: AppListRowButton(
                                key: Key('CoachChats.${chat.id}'),
                                title: chat.title,
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
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  if (state.hasConsented) ...[
                    if (chats.isEmpty) const SizedBox(height: AppSpacing.xl),
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

/// [chats] by day, newest day first: a day chat under its day, any other
/// under the local day it began. A day's own chat comes first, then the
/// rest, last answered first.
List<(String, List<CoachChat>)> _byDay(List<CoachChat> chats) {
  final days = <String, List<CoachChat>>{};
  for (final chat in chats) {
    (days[chat.day ?? localDayKey(chat.createdAt)] ??= []).add(chat);
  }
  int order(CoachChat a, CoachChat b) => a.day != b.day
      ? (a.day == null ? 1 : -1)
      : b.updatedAt.compareTo(a.updatedAt);
  return [
    for (final day in days.keys.toList()..sort((a, b) => b.compareTo(a)))
      (day, days[day]!..sort(order)),
  ];
}
