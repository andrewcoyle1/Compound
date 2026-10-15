import 'package:analytics_repository/analytics_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:compound/settings/account/cubit/edit_profile_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

class _MockAnalyticsRepository extends Mock implements AnalyticsRepository;

class _MockUserRepository extends Mock implements UserRepository;

void main() {
  late AnalyticsRepository analytics;
  late UserRepository users;
  late List<(String, LogType)> events;
  late List<Map<String, Object>> writes;

  setUpAll(() => registerFallbackValue(const AnalyticsEvent('fallback')));

  setUp(() {
    analytics = _MockAnalyticsRepository();
    users = _MockUserRepository();
    events = [];
    writes = [];
    void record(Invocation invocation) {
      final event = invocation.positionalArguments.single as LoggableEvent;
      events.add((event.eventName, event.type));
    }

    when(() => analytics.trackEvent(any())).thenAnswer(record);
    when(() => analytics.trackScreenView(any())).thenAnswer(record);
    when(() => users.updateUserFields(any(), any())).thenAnswer((invocation) {
      expect(invocation.positionalArguments.first, 'user-1');
      final fields = invocation.positionalArguments[1] as List<UserFieldValue>;
      writes.add({for (final field in fields) field.key: field.value});
      return Future.value();
    });
  });

  EditProfileCubit build([
    UserModel? user = const UserModel(userId: 'user-1'),
  ]) =>
      EditProfileCubit(userRepository: users, analytics: analytics, user: user);

  group('opening', () {
    test('shows the stored profile', () {
      final birthday = DateTime.utc(1985, 11, 5);
      final state = build(
        UserModel(
          userId: 'user-1',
          firstName: 'Provider',
          submittedFirstName: 'Andrew',
          lastName: 'Coyle',
          submittedDateOfBirth: birthday,
          submittedGender: Gender.male,
          submittedHeightCentimeters: 182.5,
          submittedExerciseFrequency: ExerciseFrequency.threeToFour,
          submittedDailyActivityLevel: ActivityLevel.light,
          submittedCardioFitnessLevel: CardioFitnessLevel.intermediate,
          isPrivate: true,
          username: 'andrew',
        ),
      ).state;

      expect(state.firstName, 'Andrew');
      expect(state.lastName, 'Coyle');
      expect(state.dateOfBirth, birthday);
      expect(state.gender, Gender.male);
      expect(state.height, 182.5);
      expect(state.heightUnit, LengthUnitPreference.centimeters);
      expect(state.exerciseFrequency, ExerciseFrequency.threeToFour);
      expect(state.cardioFitnessLevel, CardioFitnessLevel.intermediate);
      expect(state.activityLevel, ActivityLevel.light);
      expect(state.isPrivate, isTrue);
      expect(state.username, 'andrew');
    });

    test('falls back to the sign-in name, and defaults to public', () {
      final state = build(
        const UserModel(userId: 'user-1', firstName: 'Ann', lastName: 'Lee'),
      ).state;
      expect(state.firstName, 'Ann');
      expect(state.lastName, 'Lee');
      expect(state.isPrivate, isFalse);
      expect(state.dateOfBirth, isNull);
    });

    test('without a profile leaves the fields blank', () {
      final state = build(null).state;
      expect(state.uid, isNull);
      expect(state.firstName, isEmpty);
      expect(state.canSave, isFalse);
    });

    test('appearing and leaving are tracked', () {
      build()
        ..appeared()
        ..disappeared();
      expect(events, [
        ('AccountView_Appear', LogType.analytic),
        ('AccountView_Disappear', LogType.analytic),
      ]);
    });
  });

  group('what can be saved', () {
    test('a profile cannot be saved without a first name', () {
      final cubit = build();
      expect(cubit.state.canSave, isFalse);
      cubit.firstNameChanged('   ');
      expect(cubit.state.canSave, isFalse);
      cubit.firstNameChanged('Andrew');
      expect(cubit.state.canSave, isTrue);
    });

    blocTest<EditProfileCubit, EditProfileState>(
      'saving without a name writes nothing',
      build: build,
      act: (cubit) => cubit.savePressed(),
      expect: () => const <EditProfileState>[],
      verify: (_) => expect(writes, isEmpty),
    );

    blocTest<EditProfileCubit, EditProfileState>(
      'saving without a profile writes nothing',
      build: () => build(null),
      act: (cubit) async {
        cubit.firstNameChanged('Andrew');
        await cubit.savePressed();
      },
      verify: (_) => expect(writes, isEmpty),
    );
  });

  group('height', () {
    test('only counts when it is a positive number', () {
      final cubit = build();
      for (final value in [null, 0.0, -4.0]) {
        cubit.heightChanged(value);
        expect(cubit.state.heightCentimeters, isNull);
      }
      cubit.heightChanged(182.5);
      expect(cubit.state.heightCentimeters, 182.5);
    });

    blocTest<EditProfileCubit, EditProfileState>(
      'a stored height survives a round trip: untouched, it is not written',
      build: () => build(
        const UserModel(
          userId: 'user-1',
          firstName: 'Andrew',
          submittedHeightCentimeters: 182.5,
        ),
      ),
      act: (cubit) => cubit.savePressed(),
      verify: (cubit) {
        expect(cubit.state.height, 182.5);
        expect(writes.single, {
          'submitted_first_name': 'Andrew',
          'submitted_last_name': '',
        });
      },
    );

    blocTest<EditProfileCubit, EditProfileState>(
      'is typed in the chosen length unit and stored in centimetres',
      build: () => build(
        const UserModel(
          userId: 'user-1',
          firstName: 'Andrew',
          submittedHeightCentimeters: 180,
          submittedLengthUnitPreference: LengthUnitPreference.inches,
        ),
      ),
      act: (cubit) {
        expect(cubit.state.heightUnit, LengthUnitPreference.inches);
        expect(cubit.state.height, 70.9);
        cubit.heightChanged(70);
        return cubit.savePressed();
      },
      verify: (_) => expect(
        writes.single['submitted_height_centimeters']! as double,
        closeTo(177.8, 0.001),
      ),
    );

    blocTest<EditProfileCubit, EditProfileState>(
      'an emptied field does not overwrite the stored height',
      build: () => build(
        const UserModel(
          userId: 'user-1',
          firstName: 'Andrew',
          submittedHeightCentimeters: 182.5,
        ),
      ),
      act: (cubit) async {
        cubit.heightChanged(null);
        await cubit.savePressed();
      },
      verify: (_) => expect(
        writes.single.containsKey('submitted_height_centimeters'),
        isFalse,
      ),
    );
  });

  group('saving', () {
    blocTest<EditProfileCubit, EditProfileState>(
      'every field is saved under its own key, and nothing else',
      build: build,
      act: (cubit) async {
        cubit
          ..firstNameChanged('Andrew')
          ..lastNameChanged('Coyle')
          ..dateOfBirthChanged(DateTime(1985, 11, 5))
          ..genderChanged(Gender.male)
          ..heightChanged(182)
          ..cardioFitnessLevelChanged(CardioFitnessLevel.advanced)
          ..exerciseFrequencyChanged(ExerciseFrequency.fiveToSix)
          ..activityLevelChanged(ActivityLevel.veryActive);
        await cubit.savePressed();
      },
      verify: (_) => expect(writes, [
        {
          'submitted_first_name': 'Andrew',
          'submitted_last_name': 'Coyle',
          'submitted_date_of_birth': DateTime(1985, 11, 5),
          'submitted_gender': 'male',
          'submitted_height_centimeters': 182.0,
          'submitted_cardio_fitness_level': 'advanced',
          'submitted_exercise_frequency': '5-6',
          'submitted_daily_activity_level': 'very_active',
        },
      ]),
    );

    blocTest<EditProfileCubit, EditProfileState>(
      'prefer not to say is saved as a sex',
      build: build,
      act: (cubit) async {
        cubit
          ..firstNameChanged('Andrew')
          ..genderChanged(Gender.preferNotToSay);
        await cubit.savePressed();
      },
      verify: (_) =>
          expect(writes.single['submitted_gender'], 'prefer_not_to_say'),
    );

    blocTest<EditProfileCubit, EditProfileState>(
      'names are trimmed; unset pickers and an unset birthday are left out',
      build: build,
      act: (cubit) async {
        cubit
          ..firstNameChanged('  Andrew ')
          ..lastNameChanged(' Coyle  ')
          ..genderChanged(Gender.female)
          ..genderChanged(null);
        await cubit.savePressed();
      },
      verify: (_) => expect(writes.single, {
        'submitted_first_name': 'Andrew',
        'submitted_last_name': 'Coyle',
      }),
    );

    blocTest<EditProfileCubit, EditProfileState>(
      'a successful save is tracked and closes the screen',
      build: () => build(const UserModel(userId: 'user-1', firstName: 'A')),
      act: (cubit) => cubit.savePressed(),
      expect: () => [
        isA<EditProfileState>().having(
          (s) => s.status,
          'status',
          EditProfileStatus.saving,
        ),
        isA<EditProfileState>().having(
          (s) => s.status,
          'status',
          EditProfileStatus.saved,
        ),
      ],
      verify: (_) => expect(events, [
        ('AccountView_SaveProfile_Start', LogType.analytic),
        ('profile_edit_save_success', LogType.analytic),
        ('AccountView_SaveProfile_Success', LogType.analytic),
      ]),
    );

    blocTest<EditProfileCubit, EditProfileState>(
      'a failed save is reported and the screen stays',
      setUp: () =>
          when(() => users.updateUserFields(any(), any()))
              .thenThrow(Exception('offline')),
      build: () => build(const UserModel(userId: 'user-1', firstName: 'A')),
      act: (cubit) => cubit.savePressed(),
      expect: () => [
        isA<EditProfileState>().having(
          (s) => s.status,
          'status',
          EditProfileStatus.saving,
        ),
        isA<EditProfileState>().having(
          (s) => s.status,
          'status',
          EditProfileStatus.saveFailure,
        ),
      ],
      verify: (_) => expect(events, [
        ('AccountView_SaveProfile_Start', LogType.analytic),
        ('profile_edit_save_failed', LogType.analytic),
        ('AccountView_SaveProfile_Fail', LogType.severe),
      ]),
    );

    test('Cancel is tracked and writes nothing', () {
      build().cancelPressed();
      expect(events, [('AccountView_Cancel_Pressed', LogType.analytic)]);
      expect(writes, isEmpty);
    });
  });

  group('privacy', () {
    blocTest<EditProfileCubit, EditProfileState>(
      'the switch writes is_private the moment it flips',
      build: () => build(const UserModel(userId: 'user-1', isPrivate: true)),
      act: (cubit) => cubit.privacyChanged(isPrivate: false),
      verify: (cubit) {
        expect(cubit.state.isPrivate, isFalse);
        expect(writes, [
          {'is_private': false},
        ]);
        expect(events, [
          ('AccountView_Privacy_Toggle', LogType.analytic),
          ('AccountView_UpdatePrivacy_Start', LogType.analytic),
          ('AccountView_UpdatePrivacy_Success', LogType.analytic),
        ]);
      },
    );

    blocTest<EditProfileCubit, EditProfileState>(
      'a write that fails puts the switch back and says so',
      setUp: () =>
          when(() => users.updateUserFields(any(), any()))
              .thenThrow(Exception('offline')),
      build: build,
      act: (cubit) => cubit.privacyChanged(isPrivate: true),
      expect: () => [
        isA<EditProfileState>().having((s) => s.isPrivate, 'isPrivate', true),
        isA<EditProfileState>()
            .having((s) => s.isPrivate, 'isPrivate', false)
            .having(
              (s) => s.status,
              'status',
              EditProfileStatus.privacyFailure,
            ),
      ],
      verify: (_) => expect(events.last, (
        'AccountView_UpdatePrivacy_Fail',
        LogType.severe,
      )),
    );

    blocTest<EditProfileCubit, EditProfileState>(
      'without a profile, nothing is written',
      build: () => build(null),
      act: (cubit) => cubit.privacyChanged(isPrivate: true),
      expect: () => const <EditProfileState>[],
      verify: (_) => expect(writes, isEmpty),
    );
  });
}
