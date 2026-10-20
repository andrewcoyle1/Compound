// The analytics settings' single-field writes, checked against the
// Firestore contract: each writes its own field, and a document they create
// is one Swift decodes.
import 'package:body_repository/body_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/contract.dart';

void main() {
  group('FirestoreBodyRepository analytics settings writes', () {
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

    test('saveStepGoal creates a document Swift decodes when there is '
        'none: the minimal fixture with the goal', () async {
      const uid = 'user_contract_minimal';

      await subject.saveStepGoal(uid, 9000);

      expect(
        await stored(uid),
        strictlyEquals({
          ...taggedFixture('analytics_settings', 'minimal'),
          'daily_step_goal': 9000,
        }),
      );
      expect((await subject.watchAnalyticsSettings(uid).first).stepGoal, 9000);
    });

    test('saveHiddenSections creates a document Swift decodes when there is '
        'none', () async {
      const uid = 'user_contract_minimal';

      await subject.saveHiddenSections(uid, const ['habits']);

      expect(
        await stored(uid),
        strictlyEquals({
          ...taggedFixture('analytics_settings', 'minimal'),
          'hidden_section_ids': ['habits'],
        }),
      );
    });

    test('saveStepGoal writes only the goal: hidden sections changed on '
        'another device, and an unknown field, survive', () async {
      const uid = 'user_contract_full';
      await document(uid).set({
        ...storedFixture('analytics_settings', 'full'),
        'field_from_a_newer_build': 1,
      });
      // Another device hides a section after this one last read the
      // document.
      await document(uid).update({
        'hidden_section_ids': ['habits'],
      });

      await subject.saveStepGoal(uid, 6000);

      expect(
        await stored(uid),
        strictlyEquals({
          ...taggedFixture('analytics_settings', 'full'),
          'hidden_section_ids': ['habits'],
          'daily_step_goal': 6000,
          'field_from_a_newer_build': 1,
        }),
      );
    });

    test('saveHiddenSections writes only the sections: a step goal changed '
        'on another device survives', () async {
      const uid = 'user_contract_full';
      await document(uid).set(storedFixture('analytics_settings', 'full'));
      await document(uid).update({'daily_step_goal': 15000});

      await subject.saveHiddenSections(uid, const []);

      expect(
        await stored(uid),
        strictlyEquals({
          ...taggedFixture('analytics_settings', 'full'),
          'hidden_section_ids': <Object?>[],
          'daily_step_goal': 15000,
        }),
      );
    });
  });

  group('InMemoryBodyRepository analytics settings writes', () {
    const uid = 'me';

    test(
      'saveHiddenSections saves new settings, and watchers see them',
      () async {
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

        await subject.saveHiddenSections(uid, const ['habits']);

        await expectation;
      },
    );

    test('each write keeps the other field, and other users apart', () async {
      final subject = InMemoryBodyRepository(
        analyticsSettings: const AnalyticsSettings(
          authorId: uid,
          dailyStepGoal: 6000,
        ),
      );

      await subject.saveHiddenSections(uid, const ['habits']);
      var mine = await subject.watchAnalyticsSettings(uid).first;
      expect(mine.hiddenSectionIds, ['habits']);
      expect(mine.dailyStepGoal, 6000);

      await subject.saveStepGoal(uid, 9000);
      mine = await subject.watchAnalyticsSettings(uid).first;
      expect(mine.hiddenSectionIds, ['habits']);
      expect(mine.dailyStepGoal, 9000);

      expect(
        (await subject.watchAnalyticsSettings('you').first).hiddenSectionIds,
        isEmpty,
      );
    });

    test(
      'saveStepGoal with no settings stored starts from the defaults',
      () async {
        final subject = InMemoryBodyRepository();

        await subject.saveStepGoal(uid, 9000);

        final mine = await subject.watchAnalyticsSettings(uid).first;
        expect(mine.toFirestore(), {
          'id': 'analytics_settings',
          'author_id': uid,
          'hidden_section_ids': <String>[],
          'daily_step_goal': 9000,
        });
      },
    );
  });
}
