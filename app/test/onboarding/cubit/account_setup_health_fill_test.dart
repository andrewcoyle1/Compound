import 'package:body_repository/body_repository.dart';
import 'package:compound/onboarding/account_setup/account_setup_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_repository/health_repository.dart';
import 'package:image_repository/image_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';
import 'helpers.dart';

/// Ported from Swift's `OnboardingAppleHealthFillTests`: "Fill from Apple
/// Health" on the sex, date of birth, height and weight questions. A fill
/// sets the control; nothing found leaves it as it was and says so.
void main() {
  final now = DateTime(2026, 10, 15, 9, 30);
  late FakeHealthPlatform platform;
  late RecordingAnalytics analytics;
  late UserRepository users;

  setUpAll(() => registerFallbackValue(<UserFieldValue>[]));

  setUp(() {
    platform = FakeHealthPlatform();
    analytics = RecordingAnalytics();
    users = MockUserRepository();
    when(() => users.updateUserFields(any(), any())).thenAnswer((_) async {});
  });

  /// The cubit on [question], reached as a person would.
  Future<AccountSetupCubit> at(AccountQuestion question) async {
    final cubit = AccountSetupCubit(
      userRepository: users,
      analyticsRepository: analytics.repository,
      uid: 'uid',
      images: InMemoryImageRepository(),
      picker: FakePhotoPicker(),
      now: now,
      health: HealthRepository(
        platform: platform,
        body: InMemoryBodyRepository(),
        nutrition: InMemoryNutritionRepository(),
      ),
    )..firstNameChanged('Ada');
    await cubit.saveName();
    if (question == AccountQuestion.gender) return cubit;
    cubit
      ..genderSelected(Gender.male)
      ..genderContinued();
    if (question == AccountQuestion.dateOfBirth) return cubit;
    cubit.dateOfBirthContinued();
    if (question == AccountQuestion.height) return cubit;
    cubit.heightContinued();
    return cubit;
  }

  /// The fill events, by name and whether something was found.
  List<(String, Object?)> fills() => [
    for (final event in analytics.events)
      if (event.eventName.endsWith('_FillFromHealth'))
        (event.eventName, event.parameters?['found']),
  ];

  test('fill selects the sex Health holds', () async {
    platform.biologicalSex = Gender.female;
    final cubit = await at(AccountQuestion.gender);

    await cubit.fillFromHealthPressed();

    expect(cubit.state.healthFill, HealthFill.filled);
    expect(cubit.state.gender, Gender.female);
    expect(fills(), [('GenderView_FillFromHealth', true)]);
    expect(platform.requested, [HealthScope.sex]);
  });

  test('nothing found leaves the chosen sex alone and says so', () async {
    final cubit = await at(AccountQuestion.gender);
    cubit.genderSelected(Gender.male);

    await cubit.fillFromHealthPressed();

    expect(cubit.state.healthFill, HealthFill.notFound);
    expect(cubit.state.gender, Gender.male);
    expect(fills(), [('GenderView_FillFromHealth', false)]);
  });

  test('fill sets the stored date of birth', () async {
    platform.birthDate = DateTime(1986, 3, 4);
    final cubit = await at(AccountQuestion.dateOfBirth);

    await cubit.fillFromHealthPressed();

    expect(cubit.state.healthFill, HealthFill.filled);
    final date = cubit.state.dateOfBirth;
    expect((date.year, date.month, date.day), (1986, 3, 4));
  });

  test(
    "a stored date outside the picker's range counts as nothing found",
    () async {
      platform.birthDate = DateTime(2026, 11, 14);
      final cubit = await at(AccountQuestion.dateOfBirth);
      final before = cubit.state.dateOfBirth;

      await cubit.fillFromHealthPressed();

      expect(cubit.state.healthFill, HealthFill.notFound);
      expect(cubit.state.dateOfBirth, before);
    },
  );

  test('fill sets both height wheels from the latest sample', () async {
    platform.heightCentimeters = 182.4;
    final cubit = await at(AccountQuestion.height);

    await cubit.fillFromHealthPressed();

    expect(cubit.state.healthFill, HealthFill.filled);
    expect(cubit.state.centimetres, 182);
    // 182 cm is 71.65 in, which rounds to 6 ft 0 in.
    expect((cubit.state.feet, cubit.state.inches), (6, 0));
    expect(fills(), [('HeightView_FillFromHealth', true)]);
  });

  test('nothing found leaves the height wheel as it was', () async {
    final cubit = await at(AccountQuestion.height);

    await cubit.fillFromHealthPressed();

    expect(cubit.state.healthFill, HealthFill.notFound);
    expect(cubit.state.centimetres, 175);
  });

  test('fill sets both weight wheels from the latest sample', () async {
    platform.weightSamples.add(
      HealthSample(uuid: 'W', value: 81.6, date: DateTime(2026, 10, 14)),
    );
    final cubit = await at(AccountQuestion.weight);

    await cubit.fillFromHealthPressed();

    expect(cubit.state.healthFill, HealthFill.filled);
    expect(cubit.state.kilograms, 82);
    expect(cubit.state.pounds, 181);
    expect(fills(), [('WeightView_FillFromHealth', true)]);
  });

  test('nothing found leaves the weight wheel as it was', () async {
    final cubit = await at(AccountQuestion.weight);

    await cubit.fillFromHealthPressed();

    expect(cubit.state.healthFill, HealthFill.notFound);
    expect(cubit.state.kilograms, 70);
  });

  test('moving on clears what the last fill said', () async {
    platform.heightCentimeters = 170;
    final cubit = await at(AccountQuestion.height);
    await cubit.fillFromHealthPressed();
    expect(cubit.state.healthFill, HealthFill.filled);

    cubit.heightContinued();

    expect(cubit.state.healthFill, HealthFill.idle);
  });

  test('questions with nothing to fill, and no Health, do nothing', () async {
    final cubit = await at(AccountQuestion.gender);
    cubit.back();
    await cubit.fillFromHealthPressed();
    expect(cubit.state.healthFill, HealthFill.idle);

    final without = AccountSetupCubit(
      userRepository: users,
      analyticsRepository: analytics.repository,
      uid: 'uid',
      images: InMemoryImageRepository(),
      picker: FakePhotoPicker(),
      now: now,
    );
    await without.fillFromHealthPressed();
    expect(without.state.healthFill, HealthFill.idle);
    expect(fills(), isEmpty);
  });
}
