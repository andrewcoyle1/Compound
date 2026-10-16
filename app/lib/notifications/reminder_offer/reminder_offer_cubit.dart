import 'dart:async';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:device_store/device_store.dart';
import 'package:equatable/equatable.dart';
import 'package:notifications_repository/notifications_repository.dart';
import 'package:user_repository/user_repository.dart';

/// Swift's `ReminderOfferFlow.Offer` raw values and device keys.
extension ReminderOfferKeys on ReminderOffer {
  /// Swift's raw value, in the events and the device key.
  String get value => switch (this) {
    ReminderOffer.mealReminders => 'meal_reminders',
    ReminderOffer.streakReminder => 'streak_reminder',
  };

  /// Set when the offer is shown, so it is shown once on this device
  /// whatever happens next (Swift's `UserDefaults` key).
  String get shownKey => 'hasShownReminderOffer_$value';
}

/// The offer to show, if any: [offerId] counts them, so the view shows each
/// once. [saveFailures] counts answers that failed to save.
final class const ReminderOfferState({
  final ReminderOffer? offer,
  final int streakWeeks = 0,
  final int offerId = 0,
  final int saveFailures = 0,
}) extends Equatable {
  @override
  List<Object?> get props => [offer, streakWeeks, offerId, saveFailures];
}

/// Swift's `ReminderOfferFlow`: meal reminders and the streak reminder are
/// off until chosen, and each is offered once, where it becomes relevant.
/// Either answer is written to the private settings, so another device
/// does not offer it again; Notification Settings changes it afterwards.
///
/// The settings are read before anything is offered: a request made before
/// they arrive waits for them, so an answer given on another device is
/// never asked again here.
class ReminderOfferCubit extends Cubit<ReminderOfferState> {
  new({
    required UserRepository users,
    required this._notifications,
    required this._analytics,
    required this._store,
    required this._uid,
  }) : _users = users,
       super(const ReminderOfferState()) {
    _subscription = users
        .watchPrivateSettings(_uid)
        .listen(_settingsChanged, onError: (Object _, StackTrace _) {});
  }

  final UserRepository _users;
  final NotificationsRepository _notifications;
  final AnalyticsRepository _analytics;
  final DeviceStore _store;
  final String _uid;
  late final StreamSubscription<PrivateUserSettings?> _subscription;

  PrivateUserSettings? _settings;
  (ReminderOffer, int)? _waiting;

  void _settingsChanged(PrivateUserSettings? settings) {
    _settings = settings ?? const PrivateUserSettings();
    if (_waiting case (final offer, final weeks)?) {
      _waiting = null;
      _present(offer, weeks);
    }
  }

  /// Unanswered in the private settings (on any device) and not yet shown
  /// on this one (`ReminderOffer.shouldOffer`). False until the settings
  /// are read.
  bool shouldOffer(ReminderOffer offer, {int streakWeeks = 0}) {
    final settings = _settings;
    return settings != null &&
        offer.shouldOffer(
          settings: settings,
          shownOnDevice: _store.getBool(offer.shownKey) ?? false,
          streakWeeks: streakWeeks,
        );
  }

  /// For Nutrition's appear.
  void offerMealRemindersIfNeeded() => _request(ReminderOffer.mealReminders, 0);

  /// For wherever the streak, [weeks] long, is seen to have grown.
  void offerStreakReminderIfNeeded(int weeks) =>
      _request(ReminderOffer.streakReminder, weeks);

  void _request(ReminderOffer offer, int weeks) {
    if (_settings == null) {
      _waiting = (offer, weeks);
    } else {
      _present(offer, weeks);
    }
  }

  void _present(ReminderOffer offer, int weeks) {
    if (isClosed || !shouldOffer(offer, streakWeeks: weeks)) return;
    _store.setBool(offer.shownKey, value: true);
    _analytics.analytic('ReminderOffer_Shown', {'offer': offer.value});
    emit(
      ReminderOfferState(
        offer: offer,
        streakWeeks: weeks,
        offerId: state.offerId + 1,
        saveFailures: state.saveFailures,
      ),
    );
  }

  /// Either answer is written, so the offer is not made again on another
  /// device. Saying yes asks for notification permission first when it has
  /// never been asked. Meal reminders are then scheduled on the device by
  /// `NotificationsCubit`, which follows the same settings; the streak
  /// reminder is the server's.
  Future<void> answer(ReminderOffer offer, {required bool accepted}) async {
    final parameters = {'offer': offer.value, 'accepted': accepted};
    _analytics.analytic('ReminderOffer_Answered', parameters);
    if (accepted) {
      try {
        if (await _notifications.permission() == PushPermission.notDetermined) {
          await _notifications.requestPermission();
        }
      } on Object catch (error) {
        _analytics.trackEvent(
          AnalyticsEvent(
            'ReminderOffer_RequestPermission_Fail',
            parameters: {'offer': offer.value, 'error_description': '$error'},
            type: LogType.warning,
          ),
        );
      }
    }
    _analytics.analytic('ReminderOffer_Save_Start', parameters);
    try {
      await _users.mergePrivateSettings(_uid, switch (offer) {
        ReminderOffer.mealReminders => PrivateUserSettings(
          pushMealReminders: accepted,
        ),
        ReminderOffer.streakReminder => PrivateUserSettings(
          socialPushStreakReminder: accepted,
        ),
      });
      _analytics.analytic('ReminderOffer_Save_Success', parameters);
    } on Object catch (error) {
      _analytics.severe('ReminderOffer_Save_Fail', error, {
        'offer': offer.value,
      });
      if (!isClosed) {
        emit(
          ReminderOfferState(
            offer: state.offer,
            streakWeeks: state.streakWeeks,
            offerId: state.offerId,
            saveFailures: state.saveFailures + 1,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
