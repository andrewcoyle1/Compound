import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';

import '../helpers/contract.dart';

void main() {
  group(FirestoreProgramRepository, () {
    const uid = 'user_contract_full';
    late FakeFirebaseFirestore firestore;
    late List<(String, Object)> decodeErrors;
    late FirestoreProgramRepository subject;

    DocumentReference<Map<String, dynamic>> document(String path) =>
        firestore.doc(path);
    Future<Map<String, Object?>> stored(String path) async =>
        storedAsTagged((await document(path).get()).data()!);

    setUp(() {
      firestore = FakeFirebaseFirestore();
      decodeErrors = [];
      subject = FirestoreProgramRepository(
        firestore: firestore,
        onDecodeError: (path, error, _) => decodeErrors.add((path, error)),
      );
    });

    group('watchMesocycles', () {
      test('reads the full fixture back exactly', () async {
        await document('users/$uid/mesocycles/mesocycle_contract_full')
            .set(storedFixture('mesocycle', 'full'));

        final read = await subject.watchMesocycles(uid).first;

        expect(
          firestoreToTaggedJson(read.single.toFirestore()),
          strictlyEquals(taggedFixture('mesocycle', 'full')),
        );
        expect(read.single.dateCreated.isUtc, isTrue);
        expect(decodeErrors, isEmpty);
      });

      test('skips, and reports, a document that does not decode', () async {
        await document('users/$uid/mesocycles/broken').set({'id': 'broken'});

        expect(await subject.watchMesocycles(uid).first, isEmpty);
        expect(decodeErrors.single.$1, 'users/$uid/mesocycles/broken');
      });

      test('logs a decode error when no handler is given', () async {
        await document('users/$uid/mesocycles/broken').set({'id': 'broken'});

        expect(
          await FirestoreProgramRepository(firestore: firestore)
              .watchMesocycles(uid)
              .first,
          isEmpty,
        );
      });
    });

    group('watchMacrocycles', () {
      test('reads the full fixture back exactly, and re-emits', () async {
        final ids = subject
            .watchMacrocycles(uid)
            .map((macrocycles) => [for (final m in macrocycles) m.id]);
        final expectation = expectLater(
          ids,
          emitsInOrder([
            <String>[],
            ['macrocycle_contract_full'],
          ]),
        );
        await Future<void>.delayed(Duration.zero);
        await document('users/$uid/macrocycles/macrocycle_contract_full')
            .set(storedFixture('macrocycle', 'full'));
        await expectation;

        final read = await subject.watchMacrocycles(uid).first;
        expect(
          firestoreToTaggedJson(read.single.toFirestore()),
          strictlyEquals(taggedFixture('macrocycle', 'full')),
        );
      });
    });

    for (final name in ['full', 'minimal']) {
      test('saveMesocycle stores the $name fixture exactly', () async {
        final mesocycle = Mesocycle.fromFirestore(
          modelFixture('mesocycle', name),
        );

        await subject.saveMesocycle(mesocycle);

        final written = await stored(
          'users/${mesocycle.authorId}/mesocycles/${mesocycle.id}',
        );
        expect(
          written,
          strictlyEquals(firestoreToTaggedJson(mesocycle.toFirestore())),
        );
        expect(written, strictlyEquals(taggedFixture('mesocycle', name)));
      });

      test('saveMacrocycle stores the $name fixture exactly', () async {
        final macrocycle = Macrocycle.fromFirestore(
          modelFixture('macrocycle', name),
        );

        await subject.saveMacrocycle(macrocycle);

        final written = await stored(
          'users/${macrocycle.authorId}/macrocycles/${macrocycle.id}',
        );
        expect(
          written,
          strictlyEquals(firestoreToTaggedJson(macrocycle.toFirestore())),
        );
        expect(written, strictlyEquals(taggedFixture('macrocycle', name)));
      });
    }

    test('saves merge, keeping a field this app does not know', () async {
      const mesocyclePath = 'users/$uid/mesocycles/mesocycle_contract_full';
      const macrocyclePath = 'users/$uid/macrocycles/macrocycle_contract_full';
      await document(mesocyclePath).set({'field_from_a_newer_build': 1});
      await document(macrocyclePath).set({'field_from_a_newer_build': 2});

      await subject.saveMesocycle(
        Mesocycle.fromFirestore(modelFixture('mesocycle', 'full')),
      );
      await subject.saveMacrocycle(
        Macrocycle.fromFirestore(modelFixture('macrocycle', 'full')),
      );

      expect(
        await stored(mesocyclePath),
        strictlyEquals({
          ...taggedFixture('mesocycle', 'full'),
          'field_from_a_newer_build': 1,
        }),
      );
      expect(
        await stored(macrocyclePath),
        strictlyEquals({
          ...taggedFixture('macrocycle', 'full'),
          'field_from_a_newer_build': 2,
        }),
      );
    });
  });
}
