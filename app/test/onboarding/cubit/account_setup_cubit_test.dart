import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/onboarding/account_setup/account_setup_cubit.dart';
import 'package:compound_models/compound_models.dart' show UserModelKeys;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';
import 'helpers.dart';

/// Mirrors `OnboardingAccountSetupPresenterTests` and
/// `OnboardingExpenditurePresenterTests`: what each screen saves, and when.
void main() {
  late UserRepository users;
  late RecordingAnalytics analytics;
  final now = DateTime(2026, 10, 15, 9, 30);

  setUpAll(() => registerFallbackValue(<UserFieldValue>[]));

  setUp(() {
    users = MockUserRepository();
    analytics = RecordingAnalytics();
    when(() => users.updateUserFields(any(), any())).thenAnswer((_) async {});
  });

  AccountSetupCubit build({bool usesMetric = true, UserModel? profile}) =>
      AccountSetupCubit(
        userRepository: users,
        analyticsRepository: analytics.repository,
        uid: 'uid',
        now: now,
        usesMetric: usesMetric,
        profile: profile,
      );

  /// Answers every question up to the expenditure screen.
  void answerAll(AccountSetupCubit cubit) => cubit
    ..genderSelected(Gender.female)
    ..genderContinued()
    ..dateOfBirthChanged(DateTime(1994, 5, 17))
    ..dateOfBirthContinued()
    ..centimetresChanged(168)
    ..heightContinued()
    ..kilogramsChanged(72)
    ..weightContinued()
    ..exerciseFrequencySelected(ExerciseFrequency.threeToFour)
    ..exerciseFrequencyContinued()
    ..activitySelected(ActivityLevel.moderate)
    ..activityContinued();

  test('opens on the name, eighteen years back, in the locale unit', () {
    final cubit = build(
      usesMetric: false,
      profile: const UserModel(userId: 'uid', firstName: 'Ada', lastName: 'L'),
    );
    expect(cubit.state.question, AccountQuestion.name);
    expect(cubit.state.dateOfBirth, DateTime(2008, 10, 15, 9, 30));
    expect(cubit.state.lengthUnit, LengthUnitPreference.inches);
    expect((cubit.state.firstName, cubit.state.lastName), ('Ada', 'L'));
    expect(analytics.names, ['NamePhotoView_Appear']);
  });

  group('the name', () {
    blocTest<AccountSetupCubit, AccountSetupState>(
      'saves trimmed, the empty last name too, then asks for sex',
      build: build,
      act: (cubit) async {
        cubit
          ..firstNameChanged('  Ada ')
          ..lastNameChanged(' ');
        await cubit.saveName();
      },
      verify: (cubit) {
        final fields = verify(() => users.updateUserFields('uid', captureAny()))
            .captured;
        expect(fieldsOf(fields.single), {
          UserModelKeys.submittedFirstName: 'Ada',
          UserModelKeys.submittedLastName: '',
        });
        expect(cubit.state.question, AccountQuestion.gender);
        expect(analytics.names, [
          'NamePhotoView_Appear',
          'NamePhoto_Save_Start',
          'NamePhoto_Save_Success',
          'NamePhotoView_Disappear',
          'GenderView_Appear',
          // blocTest closes the cubit before verifying.
          'GenderView_Disappear',
        ]);
      },
    );

    blocTest<AccountSetupCubit, AccountSetupState>(
      'is not saved when it is only whitespace',
      build: build,
      act: (cubit) async {
        cubit.firstNameChanged('   ');
        await cubit.saveName();
      },
      verify: (cubit) {
        expect(cubit.state.canSaveName, isFalse);
        verifyNever(() => users.updateUserFields(any(), any()));
      },
    );

    final error = Exception('offline');
    blocTest<AccountSetupCubit, AccountSetupState>(
      'stays on the name and says so when the save fails',
      setUp: () =>
          when(() => users.updateUserFields(any(), any())).thenThrow(error),
      build: build,
      act: (cubit) async {
        cubit.firstNameChanged('Ada');
        await cubit.saveName();
      },
      verify: (cubit) {
        expect(cubit.state.status, AccountSetupStatus.nameFailure);
        expect(cubit.state.question, AccountQuestion.name);
        final fail = analytics.last('NamePhoto_Save_Fail');
        expect(fail.type, LogType.severe);
        expect(fail.parameters, {'error_description': '$error'});
      },
    );
  });

  test('each question needs an answer before it moves on', () {
    final cubit = build()
      ..genderContinued()
      ..exerciseFrequencyContinued()
      ..activityContinued();
    expect(cubit.state.question, AccountQuestion.name);
    expect(cubit.state.answers, isNull);
  });

  test('the question navigation events are Swift names, as info', () {
    answerAll(build());
    expect(
      analytics.events
          .where((event) => event.type == LogType.info)
          .map((event) => event.eventName),
      [
        'GenderView_Navigate',
        'DateOfBirthView_Navigate',
        'HeightView_Navigate',
        'WeightView_Navigate',
        'OnboardingExerciseFreqView_Navigate',
        'ActivityLevel_Navigate',
      ],
    );
  });

  group('height and weight', () {
    test('the two height units stay in step', () {
      final cubit = build()..centimetresChanged(175);
      expect((cubit.state.feet, cubit.state.inches), (5, 9));
      cubit.feetChanged(6);
      expect(cubit.state.centimetres, 206);
      cubit.inchesChanged(0);
      expect(cubit.state.centimetres, 183);
    });

    test('weight opens in the unit matching the height', () {
      final cubit = build()
        ..lengthUnitChanged(LengthUnitPreference.inches)
        ..heightContinued();
      expect(cubit.state.weightUnit, WeightUnitPreference.pounds);
      cubit
        ..back()
        ..lengthUnitChanged(LengthUnitPreference.centimeters)
        ..heightContinued();
      expect(cubit.state.weightUnit, WeightUnitPreference.kilograms);
    });

    test('pounds are saved as Swift converts them', () {
      final cubit = build()
        ..weightUnitChanged(WeightUnitPreference.pounds)
        ..poundsChanged(200);
      expect(cubit.state.kilograms, 91);
      expect(cubit.state.weightKilograms, 200 * 0.453592);
      cubit.kilogramsChanged(80);
      expect(cubit.state.pounds, 176);
      expect(cubit.state.weightKilograms, 176 * 0.453592);
    });

    test('a weight outside the wheel cannot be continued with', () {
      final cubit = build()..kilogramsChanged(20);
      expect(cubit.state.canSubmitWeight, isFalse);
      cubit.weightUnitChanged(WeightUnitPreference.pounds);
      expect(cubit.state.canSubmitWeight, isFalse);
      cubit.weightContinued();
      expect(cubit.state.question, AccountQuestion.name);
    });
  });

  test('back steps through the questions, and not past the first', () {
    final cubit = build();
    expect(cubit.back(), isFalse);
    answerAll(cubit);
    expect(cubit.state.question, AccountQuestion.expenditure);
    expect(cubit.back(), isTrue);
    expect(cubit.state.question, AccountQuestion.activity);
  });

  group('the expenditure screen', () {
    blocTest<AccountSetupCubit, AccountSetupState>(
      'saves every answer in one update, with the Swift keys',
      build: build,
      act: (cubit) async {
        answerAll(cubit);
        await cubit.saveProfile();
      },
      verify: (cubit) {
        final captured = verify(
          () => users.updateUserFields('uid', captureAny()),
        ).captured;
        expect(fieldsOf(captured.single), {
          UserModelKeys.submittedGender: 'female',
          UserModelKeys.submittedDateOfBirth: DateTime(1994, 5, 17, 9, 30),
          UserModelKeys.submittedHeightCentimeters: 168.0,
          UserModelKeys.submittedLengthUnitPreference: 'centimeters',
          UserModelKeys.submittedWeightKilograms: 72.0,
          UserModelKeys.submittedWeightUnitPreference: 'kilograms',
          UserModelKeys.submittedDailyActivityLevel: 'moderate',
          UserModelKeys.submittedExerciseFrequency: '3-4',
        });
        expect(cubit.state.status, AccountSetupStatus.idle);
        expect(analytics.names.sublist(analytics.names.length - 3), [
          'Expenditure_SaveProfile_Start',
          'Expenditure_SaveProfile_Success',
          'ExpenditureView_Disappear',
        ]);
      },
    );

    blocTest<AccountSetupCubit, AccountSetupState>(
      'saves nothing before every answer is in',
      build: build,
      act: (cubit) => cubit.saveProfile(),
      verify: (_) => verifyNever(() => users.updateUserFields(any(), any())),
    );

    blocTest<AccountSetupCubit, AccountSetupState>(
      'reports a failed save, for a retry',
      setUp: () =>
          when(() => users.updateUserFields(any(), any()))
              .thenThrow(Exception('offline')),
      build: build,
      act: (cubit) async {
        answerAll(cubit);
        await cubit.saveProfile();
      },
      verify: (cubit) {
        expect(cubit.state.status, AccountSetupStatus.profileFailure);
        expect(
          analytics.last('Expenditure_SaveProfile_Fail').type,
          LogType.severe,
        );
      },
    );
  });

  test('closing logs the screen it was on disappearing', () async {
    final cubit = build();
    await cubit.close();
    expect(analytics.names.last, 'NamePhotoView_Disappear');
  });

  test('saving twice at once saves once', () async {
    final cubit = build()..firstNameChanged('Ada');
    await Future.wait([cubit.saveName(), cubit.saveName()]);
    verify(() => users.updateUserFields(any(), any())).called(1);
    answerAll(cubit);
    clearInteractions(users);
    await Future.wait([cubit.saveProfile(), cubit.saveProfile()]);
    verify(() => users.updateUserFields(any(), any())).called(1);
  });

  test('the date of birth keeps the time it opened at', () {
    final cubit = build()..dateOfBirthChanged(DateTime(1990, 2, 3));
    expect(cubit.state.dateOfBirth, DateTime(1990, 2, 3, 9, 30));
  });
}
