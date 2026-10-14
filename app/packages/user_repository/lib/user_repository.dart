/// Reads the signed-in user's profile (`users/{uid}`) and private settings
/// (`users/{uid}/private/settings`) from Firestore, or from memory in the
/// staging flavor. Read-only (M1).
library;

export 'package:compound_models/compound_models.dart'
    show
        ActivityLevel,
        CardioFitnessLevel,
        DistanceUnitPreference,
        ExerciseFrequency,
        Gender,
        LengthUnitPreference,
        PrivateUserSettings,
        UserModel,
        WeightUnitPreference;

export 'src/firestore_user_repository.dart';
export 'src/in_memory_user_repository.dart';
export 'src/sample_user.dart';
export 'src/user_repository.dart';
