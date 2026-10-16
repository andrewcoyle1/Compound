import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:compound/onboarding/logic/body_units.dart';
import 'package:compound/onboarding/logic/expenditure_estimate.dart';
import 'package:compound/onboarding/onboarding_analytics.dart';
import 'package:equatable/equatable.dart';
import 'package:health_repository/health_repository.dart';
import 'package:user_repository/user_repository.dart';

/// The account-setup questions, in order (Swift folders `4 - …/1–9`).
enum AccountQuestion {
  name('NamePhotoView'),
  gender('GenderView'),
  dateOfBirth('DateOfBirthView'),
  height('HeightView'),
  weight('WeightView'),
  exerciseFrequency('ExerciseFrequencyView'),
  activity('ActivityView'),
  expenditure('ExpenditureView');

  new(this.screen);

  /// The Swift screen's analytics name.
  final String screen;
}

/// Where a save has got to.
enum AccountSetupStatus { idle, saving, nameFailure, profileFailure }

/// Where "Fill from Apple Health" has got to on the question shown (Swift
/// `AppleHealthFillState`).
enum HealthFill {
  idle,
  loading,
  filled,

  /// Nothing stored, or read access refused: Health does not say which.
  notFound,
}

/// Every answer of account setup. Only the name is saved before the last
/// screen; the rest are saved together from the expenditure screen.
final class const AccountSetupState({
  required final DateTime dateOfBirth,
  final AccountQuestion question = AccountQuestion.name,
  final AccountSetupStatus status = AccountSetupStatus.idle,
  final String firstName = '',
  final String lastName = '',
  final Gender? gender,
  final LengthUnitPreference lengthUnit = LengthUnitPreference.centimeters,
  final int centimetres = 175,
  final int feet = 5,
  final int inches = 9,
  final WeightUnitPreference weightUnit = WeightUnitPreference.kilograms,
  final int kilograms = 70,
  final int pounds = 154,
  final ExerciseFrequency? exerciseFrequency,
  final ActivityLevel? activityLevel,
  final HealthFill healthFill = HealthFill.idle,
}) extends Equatable {
  /// A first name that isn't only whitespace.
  bool get canSaveName => firstName.trim().isNotEmpty;

  /// The weight to save, in kilograms (`WeightPresenter.weight`).
  double get weightKilograms => switch (weightUnit) {
    WeightUnitPreference.kilograms => kilograms.toDouble(),
    WeightUnitPreference.pounds => kilogramsFromPoundsWheel(pounds),
  };

  /// Whether the wheel shown is in range (`WeightPresenter.canSubmit`).
  bool get canSubmitWeight => switch (weightUnit) {
    WeightUnitPreference.kilograms =>
      kilograms >= kilogramsRange.min && kilograms <= kilogramsRange.max,
    WeightUnitPreference.pounds =>
      pounds >= poundsRange.min && pounds <= poundsRange.max,
  };

  /// Every answer, once the activity question has one.
  AccountAnswers? get answers {
    final gender = this.gender;
    final frequency = exerciseFrequency;
    final activity = activityLevel;
    if (gender == null || frequency == null || activity == null) return null;
    return (
      gender: gender,
      dateOfBirth: dateOfBirth,
      heightCentimetres: centimetres.toDouble(),
      lengthUnit: lengthUnit,
      weightKilograms: weightKilograms,
      weightUnit: weightUnit,
      exerciseFrequency: frequency,
      activityLevel: activity,
    );
  }

  AccountSetupState copyWith({
    AccountQuestion? question,
    AccountSetupStatus? status,
    String? firstName,
    String? lastName,
    Gender? gender,
    DateTime? dateOfBirth,
    LengthUnitPreference? lengthUnit,
    int? centimetres,
    int? feet,
    int? inches,
    WeightUnitPreference? weightUnit,
    int? kilograms,
    int? pounds,
    ExerciseFrequency? exerciseFrequency,
    ActivityLevel? activityLevel,
    HealthFill? healthFill,
  }) => AccountSetupState(
    question: question ?? this.question,
    status: status ?? this.status,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    gender: gender ?? this.gender,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    lengthUnit: lengthUnit ?? this.lengthUnit,
    centimetres: centimetres ?? this.centimetres,
    feet: feet ?? this.feet,
    inches: inches ?? this.inches,
    weightUnit: weightUnit ?? this.weightUnit,
    kilograms: kilograms ?? this.kilograms,
    pounds: pounds ?? this.pounds,
    exerciseFrequency: exerciseFrequency ?? this.exerciseFrequency,
    activityLevel: activityLevel ?? this.activityLevel,
    healthFill: healthFill ?? this.healthFill,
  );

  @override
  List<Object?> get props => [
    question,
    status,
    firstName,
    lastName,
    gender,
    dateOfBirth,
    lengthUnit,
    centimetres,
    feet,
    inches,
    weightUnit,
    kilograms,
    pounds,
    exerciseFrequency,
    activityLevel,
    healthFill,
  ];
}

/// Account setup (Swift `NamePhotoPresenter` through `ExpenditurePresenter`):
/// the name is saved on its own screen, as `updateUserName` does, and the
/// other answers in one update from the expenditure screen. The AppBloc
/// then sees the profile complete and moves on to the disclaimer.
///
/// The sex, date of birth, height and weight questions can be filled from
/// Apple Health or Health Connect. Left out: the profile photo.
class AccountSetupCubit extends Cubit<AccountSetupState> {
  /// [usesMetric] picks the height unit the screen opens on, as Swift reads
  /// the locale's measurement system. [profile] prefills the name.
  new({
    required this._userRepository,
    required this._analyticsRepository,
    required this._uid,
    required DateTime now,
    bool usesMetric = true,
    UserModel? profile,
    this._health,
  }) : _openedAt = now,
       super(
         AccountSetupState(
           // Eighteen years ago (`DateOfBirthPresenter`).
           dateOfBirth: DateTime(
             now.year - 18,
             now.month,
             now.day,
             now.hour,
             now.minute,
           ),
           firstName: profile?.firstName ?? '',
           lastName: profile?.lastName ?? '',
           lengthUnit: usesMetric
               ? LengthUnitPreference.centimeters
               : LengthUnitPreference.inches,
         ),
       ) {
    _analyticsRepository.appear(state.question.screen);
  }

  final UserRepository _userRepository;
  final AnalyticsRepository _analyticsRepository;
  final String _uid;
  final HealthRepository? _health;
  final DateTime _openedAt;

  void _go(AccountQuestion question) {
    _analyticsRepository
      ..disappear(state.question.screen)
      ..appear(question.screen);
    emit(
      state.copyWith(
        question: question,
        status: AccountSetupStatus.idle,
        healthFill: HealthFill.idle,
      ),
    );
  }

  /// "Fill from Apple Health" on the sex, date of birth, height or weight
  /// question (`GenderPresenter`, `DateOfBirthPresenter`, `HeightPresenter`,
  /// `WeightPresenter.onFillFromAppleHealthPressed`): asks for that one
  /// type, then sets the control. A value the control cannot show counts as
  /// nothing found and leaves it as it was.
  Future<void> fillFromHealthPressed() async {
    final health = _health;
    final question = state.question;
    if (health == null || state.healthFill == HealthFill.loading) return;
    emit(state.copyWith(healthFill: HealthFill.loading));
    void Function()? apply;
    switch (question) {
      case AccountQuestion.gender:
        if (await health.readSex() case final sex?) {
          apply = () => genderSelected(sex);
        }
      case AccountQuestion.dateOfBirth:
        final earliest = DateTime(
          _openedAt.year - 120,
          _openedAt.month,
          _openedAt.day,
        );
        if (await health.readDateOfBirth() case final date?
            when !date.isBefore(earliest) && !date.isAfter(_openedAt)) {
          apply = () => dateOfBirthChanged(date);
        }
      case AccountQuestion.height:
        if (await health.readLatestHeightCentimeters() case final cm?
            when cm.round() >= centimetresRange.min &&
                cm.round() <= centimetresRange.max) {
          apply = () => centimetresChanged(cm.round());
        }
      case AccountQuestion.weight:
        if (await health.readLatestWeightKilograms() case final kg?
            when kg.round() >= kilogramsRange.min &&
                kg.round() <= kilogramsRange.max) {
          apply = () => kilogramsChanged(kg.round());
        }
      case _:
        emit(state.copyWith(healthFill: HealthFill.idle));
        return;
    }
    if (isClosed || state.question != question) return;
    apply?.call();
    emit(
      state.copyWith(
        healthFill: apply == null ? HealthFill.notFound : HealthFill.filled,
      ),
    );
    _analyticsRepository.analytic('${question.screen}_FillFromHealth', {
      'found': apply != null,
    });
  }

  /// Back one question. False on the first, where there is nothing behind.
  bool back() {
    if (state.question == AccountQuestion.name) return false;
    _go(AccountQuestion.values[state.question.index - 1]);
    return true;
  }

  void firstNameChanged(String value) => emit(state.copyWith(firstName: value));

  void lastNameChanged(String value) => emit(state.copyWith(lastName: value));

  /// Saves the trimmed names (the last name even when empty, as Swift's
  /// `updateUserName` writes it), then asks for sex.
  Future<void> saveName() async {
    if (!state.canSaveName || state.status == AccountSetupStatus.saving) {
      return;
    }
    emit(state.copyWith(status: AccountSetupStatus.saving));
    _analyticsRepository.analytic('NamePhoto_Save_Start');
    try {
      await _userRepository.updateUserFields(_uid, [
        UserField.submittedFirstName(state.firstName.trim()),
        UserField.submittedLastName(state.lastName.trim()),
      ]);
      _analyticsRepository.analytic('NamePhoto_Save_Success');
      _go(AccountQuestion.gender);
    } on Object catch (error) {
      _analyticsRepository.severe('NamePhoto_Save_Fail', error);
      emit(state.copyWith(status: AccountSetupStatus.nameFailure));
    }
  }

  void genderSelected(Gender gender) => emit(state.copyWith(gender: gender));

  void genderContinued() {
    if (state.gender == null) return;
    _analyticsRepository.info('GenderView_Navigate');
    _go(AccountQuestion.dateOfBirth);
  }

  /// Keeps the time of day the date opened with, as Swift's date-only
  /// picker does.
  void dateOfBirthChanged(DateTime date) {
    final time = state.dateOfBirth;
    emit(
      state.copyWith(
        dateOfBirth: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      ),
    );
  }

  void dateOfBirthContinued() {
    _analyticsRepository.info('DateOfBirthView_Navigate');
    _go(AccountQuestion.height);
  }

  void lengthUnitChanged(LengthUnitPreference unit) =>
      emit(state.copyWith(lengthUnit: unit));

  void centimetresChanged(int centimetres) {
    final imperial = imperialHeight(centimetres);
    emit(
      state.copyWith(
        centimetres: centimetres,
        feet: imperial.feet,
        inches: imperial.inches,
      ),
    );
  }

  void feetChanged(int feet) => emit(
    state.copyWith(
      feet: feet,
      centimetres: centimetresFromImperial(feet, state.inches),
    ),
  );

  void inchesChanged(int inches) => emit(
    state.copyWith(
      inches: inches,
      centimetres: centimetresFromImperial(state.feet, inches),
    ),
  );

  /// On to weight, in the unit matching the height's
  /// (`WeightPresenter.onAppear`).
  void heightContinued() {
    _analyticsRepository.info('HeightView_Navigate');
    emit(
      state.copyWith(
        weightUnit: state.lengthUnit == LengthUnitPreference.centimeters
            ? WeightUnitPreference.kilograms
            : WeightUnitPreference.pounds,
      ),
    );
    _go(AccountQuestion.weight);
  }

  void weightUnitChanged(WeightUnitPreference unit) =>
      emit(state.copyWith(weightUnit: unit));

  void kilogramsChanged(int kilograms) => emit(
    state.copyWith(
      kilograms: kilograms,
      pounds: poundsFromKilograms(kilograms),
    ),
  );

  void poundsChanged(int pounds) => emit(
    state.copyWith(pounds: pounds, kilograms: kilogramsFromPounds(pounds)),
  );

  void weightContinued() {
    if (!state.canSubmitWeight) return;
    _analyticsRepository.info('WeightView_Navigate');
    _go(AccountQuestion.exerciseFrequency);
  }

  void exerciseFrequencySelected(ExerciseFrequency frequency) =>
      emit(state.copyWith(exerciseFrequency: frequency));

  void exerciseFrequencyContinued() {
    if (state.exerciseFrequency == null) return;
    _analyticsRepository.info('OnboardingExerciseFreqView_Navigate');
    _go(AccountQuestion.activity);
  }

  void activitySelected(ActivityLevel level) =>
      emit(state.copyWith(activityLevel: level));

  void activityContinued() {
    if (state.activityLevel == null) return;
    _analyticsRepository.info('ActivityLevel_Navigate');
    _go(AccountQuestion.expenditure);
  }

  /// Saves every answer in one update (`ExpenditurePresenter.swift:185-193`).
  /// On success the profile is complete, and the AppBloc moves on.
  Future<void> saveProfile() async {
    final answers = state.answers;
    if (answers == null || state.status == AccountSetupStatus.saving) return;
    emit(state.copyWith(status: AccountSetupStatus.saving));
    _analyticsRepository.analytic('Expenditure_SaveProfile_Start');
    try {
      await _userRepository.updateUserFields(_uid, accountSetupFields(answers));
      _analyticsRepository.analytic('Expenditure_SaveProfile_Success');
      emit(state.copyWith(status: AccountSetupStatus.idle));
    } on Object catch (error) {
      _analyticsRepository.severe('Expenditure_SaveProfile_Fail', error);
      emit(state.copyWith(status: AccountSetupStatus.profileFailure));
    }
  }

  @override
  Future<void> close() {
    _analyticsRepository.disappear(state.question.screen);
    return super.close();
  }
}
