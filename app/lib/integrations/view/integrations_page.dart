import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:compound/check_in/view/check_in_page.dart'
    show showFailureAlert;
import 'package:compound/integrations/cubit/strava_cubit.dart';
import 'package:compound/l10n/l10n.dart';
import 'package:compound/programs/view/program_widgets.dart'
    show confirmDestructive;
import 'package:compound/settings/general/view/on_dispose.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:strava_repository/strava_repository.dart';

/// Settings › Integrations (Swift `IntegrationsView`): Strava's
/// connection, past workouts to upload, the queue, a test upload outside
/// production, and disconnecting. Apple Health and Health Connect have no
/// row here, as in Swift: each is offered where it is first used.
class IntegrationsPage extends StatelessWidget {
  const new({super.key});

  /// Under Settings: `/profile/settings/integrations`.
  static const path = 'integrations';
  static const name = 'integrations';

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StravaCubit>();
    return OnDispose(
      onDispose: cubit.disappeared,
      child: _Appear(cubit: cubit),
    );
  }
}

class _Appear extends StatefulWidget {
  const new({required this.cubit});

  final StravaCubit cubit;

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.cubit.appeared());
  }

  @override
  Widget build(BuildContext context) => const IntegrationsView();
}

class IntegrationsView extends StatelessWidget {
  const new({super.key});

  /// Posts a real activity to the person's Strava account, so development
  /// and staging builds only (Swift `#if DEV || MOCK`).
  static bool get showsTestUpload => appFlavor != 'production';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<StravaCubit>();
    final state = context.watch<StravaCubit>().state;
    final athlete = state.athlete;
    return BlocListener<StravaCubit, StravaState>(
      listenWhen: (previous, current) => current.noticeId != previous.noticeId,
      listener: showStravaNotice,
      child: AppScaffold(
        appBar: AppBar(title: Text(l10n.integrationsTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.l),
            children: [
              AppSection(
                header: l10n.integrationsAvailable,
                children: [
                  AppListRow(
                    title: l10n.stravaTitle,
                    subtitle: !state.available
                        ? l10n.stravaUnavailable
                        : athlete == null
                        ? l10n.stravaNotConnected
                        : athlete.name.isEmpty
                        ? l10n.stravaConnected
                        : l10n.stravaConnectedAs(athlete.name),
                    icon: AppSymbols.cardio,
                    tint: context.appColors.workouts,
                    accessory: state.isConnecting
                        ? const AppListRowCustom(
                            CircularProgressIndicator.adaptive(),
                          )
                        : state.available && athlete == null
                        ? AppListRowCustom(
                            TextButton(
                              onPressed: () => unawaited(cubit.connect()),
                              child: Text(l10n.stravaConnect),
                            ),
                          )
                        : null,
                  ),
                  if (athlete != null) ...[
                    if (state.backfillCount > 0)
                      AppListRowButton(
                        title: l10n.stravaUploadPastWorkouts,
                        subtitle: l10n.stravaNotOnStrava(state.backfillCount),
                        icon: AppSymbols.history,
                        accessory: null,
                        onPressed: () => unawaited(cubit.backfill()),
                      ),
                    if (state.pendingCount > 0)
                      AppListRow(
                        title: l10n.stravaWaiting(state.pendingCount),
                        icon: AppSymbols.duration,
                      ),
                    if (showsTestUpload)
                      AppListRow(
                        title: l10n.stravaTestUpload,
                        icon: AppSymbols.start,
                        accessory: AppListRowCustom(
                          state.isTestingUpload
                              ? const CircularProgressIndicator.adaptive()
                              : TextButton(
                                  onPressed: () =>
                                      unawaited(cubit.testUpload()),
                                  child: Text(l10n.stravaTestUpload),
                                ),
                        ),
                      ),
                    AppListRowButton(
                      title: l10n.stravaDisconnect,
                      icon: AppSymbols.leave,
                      tint: context.appColors.danger,
                      accessory: null,
                      onPressed: state.isDisconnecting
                          ? () {}
                          : () => unawaited(_disconnect(context)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Disconnecting asks first: it was one stray tap on a row away.
  static Future<void> _disconnect(BuildContext context) async {
    final l10n = context.l10n;
    final cubit = context.read<StravaCubit>();
    if (await confirmDestructive(
      context,
      title: l10n.stravaDisconnectTitle,
      message: l10n.stravaDisconnectMessage,
      confirmLabel: l10n.stravaDisconnectConfirm,
    )) {
      await cubit.disconnect();
    }
  }
}

/// Tells [state]'s notice: an alert, a snack bar, or the offer to upload
/// past workouts. Shared by Integrations and the workout summary.
void showStravaNotice(BuildContext context, StravaState state) {
  final l10n = context.l10n;
  void tell(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
  switch (state.notice) {
    case null:
      return;
    case StravaNotice.backfillOffered:
      unawaited(_offerBackfill(context, state.noticeCount));
    case StravaNotice.backfillQueued:
      unawaited(HapticFeedback.successNotification());
      tell(l10n.stravaBackfillQueued(state.noticeCount));
    case StravaNotice.connectFailed:
      unawaited(HapticFeedback.errorNotification());
      unawaited(
        showFailureAlert(
          context,
          l10n.stravaConnectFailed,
          state.noticeFailure == StravaFailure.missingUploadPermission
              ? l10n.stravaMissingUploadPermission
              : l10n.stravaCheckConnection,
        ),
      );
    case StravaNotice.disconnectFailed:
      unawaited(HapticFeedback.errorNotification());
      unawaited(
        showFailureAlert(
          context,
          l10n.stravaDisconnectFailed,
          l10n.stravaCheckConnection,
        ),
      );
    case StravaNotice.testUploadSent:
      unawaited(HapticFeedback.successNotification());
      tell(l10n.stravaTestUploadSent);
    case StravaNotice.testUploadFailed:
      unawaited(HapticFeedback.errorNotification());
      unawaited(
        showFailureAlert(
          context,
          l10n.stravaUploadFailed,
          stravaFailureText(l10n, state.noticeFailure),
        ),
      );
  }
}

/// Swift `StravaError`'s words for [failure]; a connection problem when
/// Strava gave no reason.
String stravaFailureText(AppLocalizations l10n, StravaFailure? failure) =>
    switch (failure) {
      StravaFailure.missingUploadPermission =>
        l10n.stravaMissingUploadPermission,
      StravaFailure.notConnected ||
      StravaFailure.authorizationRevoked => l10n.stravaNotConnectedError,
      StravaFailure.rateLimited => l10n.stravaBusy,
      StravaFailure.processingFailed => l10n.stravaProcessingFailed,
      _ => l10n.stravaCheckConnection,
    };

/// Right after connecting, the workouts already logged are the obvious
/// next question.
Future<void> _offerBackfill(BuildContext context, int count) async {
  final l10n = context.l10n;
  final cubit = context.read<StravaCubit>();
  final upload = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.stravaBackfillTitle(count)),
      content: Text(l10n.stravaBackfillMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.stravaNotNow),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.stravaUploadPastWorkouts),
        ),
      ],
    ),
  );
  if (upload ?? false) await cubit.backfill();
}
