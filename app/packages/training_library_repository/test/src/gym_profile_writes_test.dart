import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../helpers/contract.dart';

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
