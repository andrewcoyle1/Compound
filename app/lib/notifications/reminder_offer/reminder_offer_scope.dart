import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:app_ui/app_ui.dart';
import 'package:compound/check_in/check_in.dart' show showFailureAlert;
import 'package:compound/l10n/l10n.dart';
import 'package:compound/notifications/reminder_offer/reminder_offer_cubit.dart';
import 'package:device_store/device_store.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:user_repository/user_repository.dart';

/// Provides [uid]'s [ReminderOfferCubit] to [child] and shows its offers:
/// a dialog with Swift's copy, the accept button and Not Now. Dismissing it
/// answers nothing, as Swift's dialog does; the offer is still not made
/// again on this device. [onCreated] makes the screen's request.
class ReminderOfferScope extends StatelessWidget {
  const new({
    required this.uid,
    required this.child,
    this.onCreated,
    super.key,
  });

  final String uid;
  final Widget child;
  final void Function(ReminderOfferCubit cubit)? onCreated;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) {
      final cubit = ReminderOfferCubit(
        users: context.read<UserRepository>(),
        notifications: context.read<NotificationsRepository>(),
        analytics: context.read<AnalyticsRepository>(),
        store: context.read<DeviceStore>(),
        uid: uid,
      );
      onCreated?.call(cubit);
      return cubit;
    },
    lazy: false,
    child: MultiBlocListener(
      listeners: [
        BlocListener<ReminderOfferCubit, ReminderOfferState>(
          listenWhen: (previous, current) =>
              current.offerId != previous.offerId && current.offer != null,
          listener: (context, state) => unawaited(_offer(context, state)),
        ),
        BlocListener<ReminderOfferCubit, ReminderOfferState>(
          listenWhen: (previous, current) =>
              current.saveFailures != previous.saveFailures,
          listener: (context, _) => unawaited(
            showFailureAlert(context, context.l10n.reminderOfferSaveFailed),
          ),
        ),
      ],
      child: child,
    ),
  );

  static Future<void> _offer(
    BuildContext context,
    ReminderOfferState state,
  ) async {
    final offer = state.offer!;
    final cubit = context.read<ReminderOfferCubit>();
    final l10n = context.l10n;
    final (title, message, accept) = switch (offer) {
      ReminderOffer.mealReminders => (
        l10n.reminderOfferMealTitle,
        l10n.reminderOfferMealMessage,
        l10n.reminderOfferMealAccept,
      ),
      ReminderOffer.streakReminder => (
        l10n.reminderOfferStreakTitle,
        l10n.reminderOfferStreakMessage(state.streakWeeks),
        l10n.reminderOfferStreakAccept,
      ),
    };
    final accepted = await showAppDialog<bool>(
      context: context,
      title: title,
      message: message,
      actions: [
        AppDialogAction(
          label: l10n.reminderOfferNotNow,
          value: false,
          role: AppDialogRole.cancel,
        ),
        AppDialogAction(
          label: accept,
          value: true,
          role: AppDialogRole.preferred,
        ),
      ],
    );
    if (accepted == null) return;
    await cubit.answer(offer, accepted: accepted);
  }
}
