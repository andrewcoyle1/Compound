import 'dart:typed_data';

import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/onboarding/account_setup/account_setup_cubit.dart';
import 'package:compound_models/compound_models.dart' show UserModelKeys;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_repository/image_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';
import 'helpers.dart';

/// Mirrors `OnboardingAccountSetupPresenterTests` and
/// `OnboardingExpenditurePresenterTests`: what each screen saves, and when.
void main() {
  late UserRepository users;
  late RecordingAnalytics analytics;
  late InMemoryImageRepository images;
  late FakePhotoPicker picker;
  final now = DateTime(2026, 10, 15, 9, 30);

  setUpAll(() => registerFallbackValue(<UserFieldValue>[]));

  setUp(() {
    users = MockUserRepository();
    analytics = RecordingAnalytics();
    images = InMemoryImageRepository();
    picker = FakePhotoPicker();
    when(() => users.updateUserFields(any(), any())).thenAnswer((_) async {});
  });

  AccountSetupCubit build({
    bool usesMetric = true,
    UserModel? profile,
    ImageRepository? store,
  }) => AccountSetupCubit(
    userRepository: users,
    analyticsRepository: analytics.repository,
    uid: 'uid',
    images: store ?? images,
    picker: picker,
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

  group('the photo (OnboardingNamePhotoPresenterTests)', () {
    List<String> photoEvents() => [
      for (final name in analytics.names)
        if (name.startsWith('NamePhoto_Photo')) name,
    ];

    Map<String, Object?> saved() => fieldsOf(
      verify(() => users.updateUserFields('uid', captureAny())).captured.single,
    );

    test('the picker handing back nothing is recorded', () async {
      picker.photo = null;
      final cubit = build();

      await cubit.photoPressed();

      expect(photoEvents(), ['NamePhoto_PhotoNotSelected']);
      expect(analytics.last('NamePhoto_PhotoNotSelected').type, LogType.info);
      expect(cubit.state.photo, isNull);
    });

    test('a photo that fails to upload stops the flow instead of being '
        'dropped', () async {
      final cubit = build(store: FailingImageRepository())
        ..firstNameChanged('Ada');
      await cubit.photoPressed();

      await cubit.saveName();

      expect(cubit.state.status, AccountSetupStatus.nameFailure);
      expect(cubit.state.question, AccountQuestion.name);
      verifyNever(() => users.updateUserFields(any(), any()));
    });

    test('a chosen photo is uploaded along with the name', () async {
      final cubit = build()..firstNameChanged('Ada');
      await cubit.photoPressed();

      await cubit.saveName();

      expect(images.images.keys, ['users/uid/profile']);
      expect(saved(), {
        UserModelKeys.submittedProfileImage: startsWith('data:image/jpeg'),
        UserModelKeys.submittedFirstName: 'Ada',
        UserModelKeys.submittedLastName: '',
      });
      expect(cubit.state.question, AccountQuestion.gender);
      expect(picker.picks, [(PhotoSource.library, PhotoSize.standard)]);
      expect(photoEvents(), [
        'NamePhoto_PhotoSelected',
        'NamePhoto_PhotoLoad_Start',
        'NamePhoto_PhotoLoad_Success',
      ]);
    });

    test('no photo means no upload is attempted', () async {
      final cubit = build()..firstNameChanged('Ada');

      await cubit.saveName();

      expect(images.images, isEmpty);
      expect(
        saved().keys,
        isNot(contains(UserModelKeys.submittedProfileImage)),
      );
    });

    test('an empty photo selection loads nothing', () async {
      picker.photo = Uint8List(0);
      final cubit = build();

      await cubit.photoPressed();

      expect(cubit.state.photo, isNull);
      expect(cubit.state.photoLoadFailed, isTrue);
      expect(photoEvents().last, 'NamePhoto_PhotoLoad_Empty');
    });

    test('a photo that cannot be read says so; a good one clears it', () async {
      picker.error = Exception('unreadable');
      final cubit = build();

      await cubit.photoPressed();

      expect(cubit.state.photoLoadFailed, isTrue);
      expect(photoEvents(), [
        'NamePhoto_PhotoSelected',
        'NamePhoto_PhotoLoad_Start',
        'NamePhoto_PhotoLoad_Fail',
      ]);
      expect(analytics.last('NamePhoto_PhotoLoad_Fail').parameters, {
        'error_description': 'Exception: unreadable',
      });

      picker.error = null;
      await cubit.photoPressed();
      expect(cubit.state.photoLoadFailed, isFalse);
      expect(cubit.state.photo, picker.photo);
    });

    test(
      'a photo is reported as set once picked, and cleared once removed',
      () async {
        final cubit = build();
        expect(cubit.state.hasPhoto, isFalse);
        expect(cubit.state.canRemovePhoto, isFalse);

        await cubit.photoPressed();
        expect(cubit.state.hasPhoto, isTrue);
        expect(cubit.state.canRemovePhoto, isTrue);

        cubit.removePhoto();
        expect(cubit.state.hasPhoto, isFalse);
        expect(cubit.state.photo, isNull);
      },
    );

    test(
      'the profile’s photo shows, the uploaded one before the account’s',
      () {
        final both = build(
          profile: const UserModel(
            userId: 'uid',
            photoUrl: 'https://account/photo',
            submittedProfileImage: 'https://uploaded/photo',
          ),
        );
        expect(both.state.storedPhoto, 'https://uploaded/photo');
        expect(both.state.hasPhoto, isTrue);

        final account = build(
          profile: const UserModel(userId: 'uid', photoUrl: 'https://a/p'),
        );
        expect(account.state.storedPhoto, 'https://a/p');
        expect(account.state.hasPhoto, isTrue);
        // The sign-in account's photo is not the app's to remove.
        expect(account.state.canRemovePhoto, isFalse);
        account.removePhoto();
        expect(account.state.storedPhoto, 'https://a/p');
      },
    );

    test('removing an uploaded photo clears it with the name, where Swift '
        'kept it', () async {
      final cubit =
          build(
              profile: const UserModel(
                userId: 'uid',
                photoUrl: 'https://account/photo',
                submittedProfileImage: 'https://uploaded/photo',
              ),
            )
            ..firstNameChanged('Ada')
            ..removePhoto();

      expect(cubit.state.storedPhoto, 'https://account/photo');
      expect(cubit.state.canRemovePhoto, isFalse);
      await cubit.saveName();

      expect(saved(), {
        UserModelKeys.submittedProfileImage: null,
        UserModelKeys.submittedFirstName: 'Ada',
        UserModelKeys.submittedLastName: '',
      });
    });

    test('Remove takes a picked photo before the uploaded one', () async {
      final cubit = build(
        profile: const UserModel(
          userId: 'uid',
          submittedProfileImage: 'https://uploaded/photo',
        ),
      );
      await cubit.photoPressed();

      cubit.removePhoto();

      expect(cubit.state.photo, isNull);
      expect(cubit.state.storedPhoto, 'https://uploaded/photo');
      expect(cubit.state.clearsUploadedPhoto, isFalse);
    });
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
