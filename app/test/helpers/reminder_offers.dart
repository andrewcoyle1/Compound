import 'package:device_store/device_store.dart';

/// A device that has already shown both reminder offers, for flows that
/// pass through Nutrition or Today and are not about the offers.
InMemoryDeviceStore offersShownDevice() => InMemoryDeviceStore({
  'hasShownReminderOffer_meal_reminders': true,
  'hasShownReminderOffer_streak_reminder': true,
});
