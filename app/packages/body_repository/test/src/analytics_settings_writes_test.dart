// saveAnalyticsSettings, checked against the Firestore contract: what is
// stored is exactly the model's canonical encoding.
import 'package:body_repository/body_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contract.dart';

void main() {
  group('FirestoreBodyRepository.saveAnalyticsSettings', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreBodyRepository subject;

    DocumentReference<Map<String, dynamic>> document(String uid) =>
        firestore.doc('users/$uid/analytics_settings/analytics_settings');
    Future<Map<String, Object?>> stored(String uid) async =>
        storedAsTagged((await document(uid).get()).data()!);

    setUp(() {
      firestore = FakeFirebaseFirestore();
      subject = FirestoreBodyRepository(firestore: firestore);
    });

    for (final name in [
      'full',
      'minimal',
      'legacy-null-optionals.expected',
      'legacy-whole-number-doubles.expected',
    ]) {
      test('stores the $name fixture as the model encodes it', () async {
        final model = AnalyticsSettings.fromFirestore(
          modelFixture('analytics_settings', name),
        );

        await subject.saveAnalyticsSettings(model);

        final written = await stored(model.authorId);
        expect(written, strictlyEquals(model.toFirestore()));
        expect(
          written,
          strictlyEquals(taggedFixture('analytics_settings', name)),
        );
      });
    }

    test('reads back through watchAnalyticsSettings', () async {
      final model = AnalyticsSettings.fromFirestore(
        modelFixture('analytics_settings', 'full'),
      );

      await subject.saveAnalyticsSettings(model);
      final read = await subject.watchAnalyticsSettings(model.authorId).first;

      expect(
        read.toFirestore(),
        strictlyEquals(taggedFixture('analytics_settings', 'full')),
      );
    });

    test('merges: an unknown field survives and a null step goal keeps the '
        'stored one, as in Swift', () async {
      final full = AnalyticsSettings.fromFirestore(
        modelFixture('analytics_settings', 'full'),
      );
      await document(full.authorId).set({
        ...storedFixture('analytics_settings', 'full'),
        'field_from_a_newer_build': 1,
      });

      final change = AnalyticsSettings(
        authorId: full.authorId,
        hiddenSectionIds: const ['nutrition'],
      );
      await subject.saveAnalyticsSettings(change);

      expect(
        await stored(full.authorId),
        strictlyEquals({
          ...taggedFixture('analytics_settings', 'full'),
          ...change.toFirestore(),
          'field_from_a_newer_build': 1,
        }),
      );
    });
  });

  group('InMemoryBodyRepository.saveAnalyticsSettings', () {
    const uid = 'me';

    test('saves new settings, and watchers see them', () async {
      final subject = InMemoryBodyRepository();
      final hidden = subject
          .watchAnalyticsSettings(uid)
          .map((settings) => settings.hiddenSectionIds);
      final expectation = expectLater(
        hidden,
        emitsInOrder([
          <String>[],
          ['habits'],
        ]),
      );

      await subject.saveAnalyticsSettings(
        const AnalyticsSettings(authorId: uid, hiddenSectionIds: ['habits']),
      );

      await expectation;
    });

    test('merges over stored settings, keeping other users apart', () async {
      final subject = InMemoryBodyRepository(
        analyticsSettings: const AnalyticsSettings(
          authorId: uid,
          dailyStepGoal: 6000,
        ),
      );

      await subject.saveAnalyticsSettings(
        const AnalyticsSettings(authorId: uid, hiddenSectionIds: ['habits']),
      );

      final mine = await subject.watchAnalyticsSettings(uid).first;
      expect(mine.hiddenSectionIds, ['habits']);
      expect(mine.dailyStepGoal, 6000);
      expect(
        (await subject.watchAnalyticsSettings('you').first).hiddenSectionIds,
        isEmpty,
      );
    });
  });
}
