import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../helpers/contract.dart';
import '../helpers/offline_firestore.dart';

GymProfileModel _profile(String name) =>
    GymProfileModel.fromFirestore(modelFixture('gym_profile', name));

void main() {
  group('$FirestoreTrainingLibraryRepository.saveGymProfile', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreTrainingLibraryRepository subject;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      subject = FirestoreTrainingLibraryRepository(firestore: firestore);
    });

    for (final name in ['full', 'minimal']) {
      test('stores the $name fixture exactly, and reads it back', () async {
        final profile = _profile(name);

        await subject.saveGymProfile(profile);

        final document = firestore.doc(
          'users/${profile.authorId}/gym_profiles/${profile.id}',
        );
        final written = storedAsTagged((await document.get()).data()!);
        expect(
          written,
          strictlyEquals(firestoreToTaggedJson(profile.toFirestore())),
        );
        expect(written, strictlyEquals(taggedFixture('gym_profile', name)));
        final read = await subject.watchGymProfiles(profile.authorId).first;
        expect(
          firestoreToTaggedJson(read.single.toFirestore()),
          strictlyEquals(taggedFixture('gym_profile', name)),
        );
      });
    }

    test('merges, keeping a field this app does not know', () async {
      final profile = _profile('full');
      final document = firestore.doc(
        'users/${profile.authorId}/gym_profiles/${profile.id}',
      );
      await document.set({'field_from_a_newer_build': 1});

      await subject.saveGymProfile(profile);

      expect(
        storedAsTagged((await document.get()).data()!),
        strictlyEquals({
          ...taggedFixture('gym_profile', 'full'),
          'field_from_a_newer_build': 1,
        }),
      );
    });
  });

  group('$FirestoreTrainingLibraryRepository gym writes', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreTrainingLibraryRepository subject;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      subject = FirestoreTrainingLibraryRepository(firestore: firestore);
    });

    test('a cleared picture is deleted, not merged back', () async {
      final full = _profile('full');
      final document = firestore.doc(
        'users/${full.authorId}/gym_profiles/${full.id}',
      );
      await subject.saveGymProfile(full);
      final cleared = GymProfileModel.fromFirestore(
        {...full.toFirestore()}..remove(GymProfileModelKeys.imageUrl),
      );

      await subject.saveGymProfile(cleared);

      final stored = (await document.get()).data()!;
      expect(stored.containsKey(GymProfileModelKeys.imageUrl), isFalse);
      expect(stored[GymProfileModelKeys.name], full.name);
    });

    test('a removed weight is gone: each list is written whole', () async {
      final full = _profile('full');
      final document = firestore.doc(
        'users/${full.authorId}/gym_profiles/${full.id}',
      );
      await subject.saveGymProfile(full);
      final dumbbells = full.freeWeights.firstWhere(
        (weights) => weights.range.isNotEmpty,
      );
      final edited = GymEditorRules.deletingEntries(
        full,
        GymEquipmentList.freeWeights,
        dumbbells.id,
        {dumbbells.range.first.id},
      );

      await subject.saveGymProfile(edited);

      final stored = (await document.get()).data()!;
      final lists = stored[GymProfileModelKeys.freeWeights]! as List<Object?>;
      final range =
          lists.cast<Map<String, Object?>>().firstWhere(
                (item) => item[GymEquipmentKeys.id] == dumbbells.id,
              )[GymEquipmentKeys.range]!
              as List<Object?>;
      expect(range, hasLength(dumbbells.range.length - 1));
    });

    test('deleteGymProfile removes the document', () async {
      final full = _profile('full');
      await subject.saveGymProfile(full);

      await subject.deleteGymProfile(full.authorId, full.id);

      expect(await subject.watchGymProfiles(full.authorId).first, isEmpty);
    });

    test('deleteGymProfile completes offline; a refusal is reported', () async {
      FakeFirebaseFirestore();
      final offline = OfflineFirestore();
      final refused = <(String, String)>[];
      final repository = FirestoreTrainingLibraryRepository(
        firestore: offline,
        onWriteError: (path, error, _) =>
            refused.add((path, (error as FirebaseException).code)),
      );

      await repository.deleteGymProfile('u', 'g');
      expect(offline.writes, ['users/u/gym_profiles/g']);

      offline.refuse('permission-denied');
      await pumpEventQueue();
      expect(refused, [('users/u/gym_profiles/g', 'permission-denied')]);
    });
  });

  group('$InMemoryTrainingLibraryRepository.deleteGymProfile', () {
    test("removes the author's own only, telling watchers", () async {
      final gym = sampleGymProfiles.single;
      final subject = InMemoryTrainingLibraryRepository(
        gymProfiles: sampleGymProfiles,
      );
      final counts = subject
          .watchGymProfiles(gym.authorId)
          .map((profiles) => profiles.length);
      final expectation = expectLater(counts, emitsInOrder([1, 1, 0]));

      await subject.deleteGymProfile('other', gym.id);
      await subject.deleteGymProfile(gym.authorId, gym.id);
      await expectation;
    });
  });

  group('$InMemoryTrainingLibraryRepository.saveGymProfile', () {
    test('adds a new profile, then merges over it, telling watchers', () async {
      final subject = InMemoryTrainingLibraryRepository(
        gymProfiles: sampleGymProfiles,
      );
      final full = _profile('full');
      final uid = full.authorId;
      final names = subject
          .watchGymProfiles(uid)
          .map((profiles) => [for (final p in profiles) p.name]);
      final expectation = expectLater(
        names,
        emitsInOrder([
          <String>[],
          [full.name],
          ['Renamed'],
        ]),
      );

      await subject.saveGymProfile(full);
      await subject.saveGymProfile(
        GymProfileModel.fromFirestore({
          ...full.toFirestore(),
          GymProfileModelKeys.name: 'Renamed',
        }),
      );
      await expectation;

      expect(
        firestoreToTaggedJson(
          (await subject.watchGymProfiles(uid).first).single.toFirestore(),
        ),
        strictlyEquals({
          ...taggedFixture('gym_profile', 'full'),
          'name': 'Renamed',
        }),
      );
      expect(
        await subject.watchGymProfiles(sampleGymProfiles.single.authorId).first,
        sampleGymProfiles,
      );
    });
  });
}
