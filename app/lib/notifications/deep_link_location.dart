import 'package:compound/workout_tracker/view/workout_tracker_page.dart';
import 'package:notifications_repository/notifications_repository.dart';

/// Where the router goes for [link]: the Today's Workout link opens the
/// tracker when a workout is under way, as Swift's does; anything else goes
/// where the link says (`DeepLink.toLocation`), the user's own session into
/// their history.
String deepLinkLocation(
  DeepLink link, {
  String? currentUserId,
  bool workoutActive = false,
}) => link is WorkoutLink && workoutActive
    ? WorkoutTrackerPage.path
    : link.toLocation(currentUserId: currentUserId);
