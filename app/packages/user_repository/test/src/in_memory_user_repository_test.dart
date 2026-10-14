import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

void main() {
  group(InMemoryUserRepository, () {
    final now = DateTime(2026, 10, 14, 12);
    final user = sampleUser(now: now);
    final settings = sampleUserSettings(now: now);
    final subject = InMemoryUserRepository(
      users: {sampleUserId: user},
      settings: {sampleUserId: settings},
    );

    test('serves the seeded profile and settings', () async {
      expect(await subject.watchUser(sampleUserId).first, same(user));
      expect(
        await subject.watchPrivateSettings(sampleUserId).first,
        same(settings),
      );
    });

    test('serves null for anyone else', () async {
      expect(await subject.watchUser('someone').first, isNull);
      expect(await subject.watchPrivateSettings('someone').first, isNull);
    });

    test('is empty by default', () async {
      expect(
        await InMemoryUserRepository().watchUser(sampleUserId).first,
        isNull,
      );
    });
  });

  group('sampleUser', () {
    final now = DateTime(2026, 10, 14, 12);

    test('is the staging auth user, onboarded, with metric units', () {
      final user = sampleUser(now: now);
      expect(user.userId, 'mock_user_123');
      expect(user.displayName, 'Alice Cooper');
      expect(user.email, 'alice@example.com');
      expect(user.didCompleteOnboarding, isTrue);
      expect(
        user.submittedWeightUnitPreference,
        WeightUnitPreference.kilograms,
      );
      expect(
        user.submittedLengthUnitPreference,
        LengthUnitPreference.centimeters,
      );
      expect(user.weeklySessionGoal, 3);
      expect(user.creationDate, now.subtract(const Duration(days: 30)));
    });

    test('has settings that agree with the weekly goal', () {
      final settings = sampleUserSettings(now: now);
      expect(settings.weekGoal, sampleUser(now: now).weeklySessionGoal);
      expect(settings.weekSessions, lessThanOrEqualTo(settings.weekGoal!));
    });

    test('round-trips through the Firestore encoding', () {
      final user = sampleUser(now: now);
      expect(
        UserModel.fromFirestore(user.toFirestore()).toFirestore(),
        user.toFirestore(),
      );
      final settings = sampleUserSettings(now: now);
      expect(
        PrivateUserSettings.fromFirestore(settings.toFirestore()).toFirestore(),
        settings.toFirestore(),
      );
    });
  });
}
