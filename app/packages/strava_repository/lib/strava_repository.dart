/// Strava, without UI (Swift `StravaManager`): the connection held on the
/// server behind the `strava*` callables, finished workouts uploaded in
/// Strava's strength format through a queue kept per account on the device,
/// each session stamped with its activity, and the activities imported from
/// Strava, for the owner's own screens only.
library;

export 'package:compound_models/compound_models.dart'
    show StravaImportedActivity;

export 'src/fake_strava_api.dart';
export 'src/strava_account_store.dart';
export 'src/strava_api.dart';
export 'src/strava_authorizer.dart';
export 'src/strava_exercise_type.dart';
export 'src/strava_models.dart';
export 'src/strava_repository.dart';
export 'src/strava_rules.dart';
export 'src/strava_strength_file.dart';
