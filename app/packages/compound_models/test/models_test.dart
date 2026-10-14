import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

void main() {
  group('UserModel.fromFirestore', () {
    test('requires user_id and did_complete_onboarding, as Swift does', () {
      expect(
        () => UserModel.fromFirestore({'did_complete_onboarding': true}),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => UserModel.fromFirestore({'user_id': 'u'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('rejects an enum value Swift does not know', () {
      expect(
        () => UserModel.fromFirestore({
          'user_id': 'u',
          'did_complete_onboarding': false,
          'submitted_gender': 'other',
        }),
        throwsFormatException,
      );
    });

    test('reads a whole-number double written as an integer', () {
      final user = UserModel.fromFirestore({
        'user_id': 'u',
        'did_complete_onboarding': false,
        'submitted_height_centimeters': 180,
      });
      expect(user.submittedHeightCentimeters, isA<double>());
      expect(user.toFirestore()['submitted_height_centimeters'], 180.0);
    });

    test('defaults did_complete_onboarding to false when built in Dart', () {
      expect(const UserModel(userId: 'u').didCompleteOnboarding, isFalse);
    });
  });

  test('PrivateUserSettings with nothing set writes an empty document', () {
    expect(const PrivateUserSettings().toFirestore(), isEmpty);
  });
}
