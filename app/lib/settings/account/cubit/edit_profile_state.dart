part of 'edit_profile_cubit.dart';

enum EditProfileStatus {
  /// Being edited.
  editing,

  /// Save is writing.
  saving,

  /// Saved: the view closes the screen.
  saved,

  /// Save failed; nothing was written and the screen stays.
  saveFailure,

  /// The privacy switch could not be written and was put back.
  privacyFailure,
}

final class EditProfileState extends Equatable {
  const new({
    this.uid,
    this.firstName = '',
    this.lastName = '',
    this.dateOfBirth,
    this.gender,
    this.heightUnit = LengthUnitPreference.centimeters,
    this.height,
    this.prefilledHeight,
    this.cardioFitnessLevel,
    this.exerciseFrequency,
    this.activityLevel,
    this.isPrivate = false,
    this.username,
    this.profileImageUrl,
    this.pickedPhoto,
    this.status = EditProfileStatus.editing,
  });

  /// The stored profile, as the fields show it. The names are the ones the
  /// user gave (`submitted_*`), else the sign-in provider's: Swift prefills
  /// from the provider's only, so a name changed here reads back as the
  /// provider's next time.
  factory from(UserModel? user) {
    if (user == null) return const EditProfileState();
    final unit =
        user.submittedLengthUnitPreference ?? LengthUnitPreference.centimeters;
    final centimetres = user.submittedHeightCentimeters;
    final height = centimetres == null
        ? null
        : _oneDecimal(
            unit == LengthUnitPreference.inches
                ? centimetres / centimetresPerInch
                : centimetres,
          );
    return EditProfileState(
      uid: user.userId,
      firstName: user.submittedFirstName ?? user.firstName ?? '',
      lastName: user.submittedLastName ?? user.lastName ?? '',
      dateOfBirth: user.submittedDateOfBirth,
      gender: user.submittedGender,
      heightUnit: unit,
      height: height,
      prefilledHeight: height,
      cardioFitnessLevel: user.submittedCardioFitnessLevel,
      exerciseFrequency: user.submittedExerciseFrequency,
      activityLevel: user.submittedDailyActivityLevel,
      isPrivate: user.isPrivate ?? false,
      username: user.username,
      profileImageUrl: user.submittedProfileImage ?? user.photoUrl,
    );
  }

  /// The profile's id; null when there is no profile to edit.
  final String? uid;
  final String firstName;
  final String lastName;

  /// Null until stored or picked. Swift's picker always holds a date, so it
  /// saves today's for someone who never gave one; this leaves it unset.
  final DateTime? dateOfBirth;
  final Gender? gender;

  /// The unit the height is typed in, chosen on the Units screen.
  final LengthUnitPreference heightUnit;

  /// The height as typed, in [heightUnit].
  final double? height;

  /// What the height field showed on opening, rounded to one decimal.
  final double? prefilledHeight;
  final CardioFitnessLevel? cardioFitnessLevel;
  final ExerciseFrequency? exerciseFrequency;
  final ActivityLevel? activityLevel;
  final bool isPrivate;

  /// Shown, not edited here yet.
  final String? username;

  /// The picture shown now: the uploaded one, else the account's.
  final String? profileImageUrl;

  /// A new photo from the library, uploaded by Save.
  final Uint8List? pickedPhoto;
  final EditProfileStatus status;

  /// A profile needs a first name.
  bool get canSave => firstName.trim().isNotEmpty;

  /// The height in centimetres, as the profile stores it; null for nothing
  /// or nothing positive, which leaves the stored height alone.
  double? get heightCentimeters {
    final height = this.height;
    if (height == null || height <= 0) return null;
    return heightUnit == LengthUnitPreference.inches
        ? height * centimetresPerInch
        : height;
  }

  /// Every edited field under its own key (Swift `profileData()`). Unset
  /// pickers and an untouched height are left out, so they never write
  /// over what is stored.
  List<UserFieldValue> get fieldsToSave {
    final heightCentimeters = this.heightCentimeters;
    final dateOfBirth = this.dateOfBirth;
    final gender = this.gender;
    final cardioFitnessLevel = this.cardioFitnessLevel;
    final exerciseFrequency = this.exerciseFrequency;
    final activityLevel = this.activityLevel;
    return [
      UserField.submittedFirstName(firstName.trim()),
      UserField.submittedLastName(lastName.trim()),
      if (dateOfBirth != null) UserField.submittedDateOfBirth(dateOfBirth),
      if (gender != null) UserField.submittedGender(gender),
      if (heightCentimeters != null && height != prefilledHeight)
        UserField.submittedHeightCentimeters(heightCentimeters),
      if (cardioFitnessLevel != null)
        UserField.submittedCardioFitnessLevel(cardioFitnessLevel),
      if (exerciseFrequency != null)
        UserField.submittedExerciseFrequency(exerciseFrequency),
      if (activityLevel != null)
        UserField.submittedDailyActivityLevel(activityLevel),
    ];
  }

  EditProfileState copyWith({
    String? firstName,
    String? lastName,
    DateTime? Function()? dateOfBirth,
    Gender? Function()? gender,
    double? Function()? height,
    CardioFitnessLevel? Function()? cardioFitnessLevel,
    ExerciseFrequency? Function()? exerciseFrequency,
    ActivityLevel? Function()? activityLevel,
    bool? isPrivate,
    Uint8List? pickedPhoto,
    EditProfileStatus? status,
  }) => EditProfileState(
    uid: uid,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    dateOfBirth: dateOfBirth != null ? dateOfBirth() : this.dateOfBirth,
    gender: gender != null ? gender() : this.gender,
    heightUnit: heightUnit,
    height: height != null ? height() : this.height,
    prefilledHeight: prefilledHeight,
    cardioFitnessLevel: cardioFitnessLevel != null
        ? cardioFitnessLevel()
        : this.cardioFitnessLevel,
    exerciseFrequency: exerciseFrequency != null
        ? exerciseFrequency()
        : this.exerciseFrequency,
    activityLevel: activityLevel != null ? activityLevel() : this.activityLevel,
    isPrivate: isPrivate ?? this.isPrivate,
    username: username,
    profileImageUrl: profileImageUrl,
    pickedPhoto: pickedPhoto ?? this.pickedPhoto,
    status: status ?? this.status,
  );

  static double _oneDecimal(double value) => (value * 10).round() / 10;

  @override
  List<Object?> get props => [
    uid,
    firstName,
    lastName,
    dateOfBirth,
    gender,
    heightUnit,
    height,
    prefilledHeight,
    cardioFitnessLevel,
    exerciseFrequency,
    activityLevel,
    isPrivate,
    username,
    profileImageUrl,
    pickedPhoto,
    status,
  ];
}
