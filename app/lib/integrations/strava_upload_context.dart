import 'package:analytics_repository/analytics_repository.dart';
import 'package:strava_repository/strava_repository.dart';
import 'package:training_library_repository/training_library_repository.dart'
    show PrebuiltCatalogue, TrainingLibraryRepository;
import 'package:user_repository/user_repository.dart';

/// What a Strava upload reads besides the session (Swift reads the same
/// from its managers): the prebuilt and the user's own exercises, for a
/// custom exercise's Strava type, and the profile's units, for the
/// description.
Future<StravaUploadContext> Function(String uid) stravaUploadContext({
  required UserRepository users,
  required TrainingLibraryRepository library,
}) => (uid) async {
  final user = await users.watchUser(uid).first;
  return (
    library: [
      ...PrebuiltCatalogue.instance.exercises,
      ...await library.watchUserExercises(uid).first,
    ],
    weightUnit:
        user?.submittedWeightUnitPreference ?? WeightUnitPreference.kilograms,
    distanceUnit:
        user?.submittedDistanceUnitPreference ??
        DistanceUnitPreference.kilometers,
  );
};

/// Reports the Strava queue's events (`strava_upload_rejected`,
/// `strava_upload_error`) at the warning level, as Swift tracks them.
StravaEventReporter stravaEvents(AnalyticsRepository analytics) =>
    (name, parameters) => analytics.trackEvent(
      AnalyticsEvent(name, parameters: parameters, type: LogType.warning),
    );
