import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compound_models/compound_models.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';

import '../helpers/contract.dart';

/// A [ProgramRepository] whose saves fail.
class _FailingPrograms extends InMemoryProgramRepository {
  @override
  Future<void> saveMesocycle(Mesocycle mesocycle) =>
      Future.error(StateError('offline'));
}

void main() {
  const uid = 'user_contract_full';
  final now = DateTime.utc(2026, 10, 15, 9, 30, 0, 125);
  const nowTagged = {r'$timestamp': '2026-10-15T09:30:00.125Z'};
  final pushPullLegs = PrebuiltCatalogue.instance.mesocycles.firstWhere(
    (mesocycle) => mesocycle.id == 'program-push-pull-legs',
  );
  late int count;
  String newId() => 'id-${++count}';

  setUp(() => count = 0);

  group('$TrainingSetupService on Firestore', () {
    late FakeFirebaseFirestore firestore;
    late TrainingSetupService subject;

    Future<Map<String, Object?>> stored(String path) async =>
        storedAsTagged((await firestore.doc(path).get()).data()!);

    Macrocycle macrocycle(String id, MacrocycleStatus status) =>
        Macrocycle.fromFirestore({
          ...modelFixture('macrocycle', 'full'),
          MacrocycleKeys.id: id,
          MacrocycleKeys.status: status.value,
        });

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      subject = TrainingSetupService(
        programs: FirestoreProgramRepository(firestore: firestore),
        library: FirestoreTrainingLibraryRepository(firestore: firestore),
        users: FirestoreUserRepository(firestore: firestore),
        now: () => now,
        newId: newId,
      );
      await firestore
          .doc('users/$uid')
          .set(storedFixture('user_model', 'full'));
    });

    group('startPrebuiltMesocycle', () {
      test('saves the copy, ends the running macrocycles, starts one of the '
          'copy and makes it the active mesocycle', () async {
        final programs = FirestoreProgramRepository(firestore: firestore);
        for (final status in MacrocycleStatus.values) {
          await programs.saveMacrocycle(macrocycle(status.value, status));
        }
        final otherUser = Macrocycle.fromFirestore({
          ...modelFixture('macrocycle', 'minimal'),
        });
        await programs.saveMacrocycle(otherUser);

        final copy = await subject.startPrebuiltMesocycle(uid, pushPullLegs);

        expect(copy.id, 'id-1');
        expect(copy.authorId, uid);
        expect(
          await stored('users/$uid/mesocycles/${copy.id}'),
          strictlyEquals(firestoreToTaggedJson(copy.toFirestore())),
        );
        final started = 'id-$count';
        expect(
          await stored('users/$uid/macrocycles/$started'),
          strictlyEquals({
            'id': started,
            'author_id': uid,
            'name': 'Push/Pull/Legs',
            'mesocycle_ids': ['id-1'],
            'status': 'active',
            'mesocycle_index': 0,
            'mesocycle_started_at': nowTagged,
            'skips': <Object?>[],
            'iteration': 1,
            'date_created': nowTagged,
            'date_modified': nowTagged,
          }),
        );
        for (final status in MacrocycleStatus.values) {
          final expected = {
            ...firestoreToTaggedJson(
              macrocycle(status.value, status).toFirestore(),
            ),
          };
          if (status == MacrocycleStatus.active ||
              status == MacrocycleStatus.completed) {
            expected['status'] = 'ended';
            expected['date_modified'] = nowTagged;
          }
          expect(
            await stored('users/$uid/macrocycles/${status.value}'),
            strictlyEquals(expected),
            reason: status.value,
          );
        }
        expect(
          await stored(
            'users/${otherUser.authorId}/macrocycles/${otherUser.id}',
          ),
          strictlyEquals(taggedFixture('macrocycle', 'minimal')),
        );
        expect(
          await stored('users/$uid'),
          strictlyEquals({
            ...taggedFixture('user_model', 'full'),
            'submitted_active_mesocycle_id': 'id-1',
          }),
        );
        expect(
          runningMacrocycle(await programs.watchMacrocycles(uid).first)?.id,
          started,
        );
      });

      test('fails at the profile update when there is no profile', () async {
        await firestore.doc('users/$uid').delete();

        await expectLater(
          subject.startPrebuiltMesocycle(uid, pushPullLegs),
          throwsA(isA<FirebaseException>()),
        );
      });
    });

    test('saveGymProfile stores the gym as the model encodes it', () async {
      final draft = newGymProfile(
        authorId: uid,
        name: ' ',
        now: DateTime.utc(2026),
        weightUnit: WeightUnitPreference.pounds,
        newId: newId,
      );

      final saved = await subject.saveGymProfile(draft);

      expect(saved.name, 'Untitled Gym Profile');
      expect(saved.dateModified, now);
      final written = await stored('users/$uid/gym_profiles/${draft.id}');
      expect(
        written,
        strictlyEquals(firestoreToTaggedJson(saved.toFirestore())),
      );
      final read = await FirestoreTrainingLibraryRepository(
        firestore: firestore,
      ).watchGymProfiles(uid).first;
      expect(
        firestoreToTaggedJson(read.single.toFirestore()),
        strictlyEquals(written),
      );
    });

    test('setFavouriteGymProfile sets that field and nothing else', () async {
      await subject.setFavouriteGymProfile(uid, 'gym-2');

      expect(
        await stored('users/$uid'),
        strictlyEquals({
          ...taggedFixture('user_model', 'full'),
          'submitted_favourite_gym_profile_id': 'gym-2',
        }),
      );
    });
  });

  group('$TrainingSetupService in memory', () {
    final user = UserModel.fromFirestore(modelFixture('user_model', 'full'));

    test('a failed mesocycle save writes nothing else', () async {
      final users = InMemoryUserRepository(users: {uid: user});
      final programs = _FailingPrograms();
      final subject = TrainingSetupService(
        programs: programs,
        library: InMemoryTrainingLibraryRepository(),
        users: users,
      );

      await expectLater(
        subject.startPrebuiltMesocycle(uid, pushPullLegs),
        throwsStateError,
      );
      expect(await programs.watchMacrocycles(uid).first, isEmpty);
      expect(
        (await users.watchUser(uid).first)!.submittedActiveMesocycleId,
        user.submittedActiveMesocycleId,
      );
    });

    test('starting twice leaves only the second running', () async {
      final users = InMemoryUserRepository(users: {uid: user});
      final programs = InMemoryProgramRepository();
      final library = InMemoryTrainingLibraryRepository();
      final subject = TrainingSetupService(
        programs: programs,
        library: library,
        users: users,
      );

      final first = await subject.startPrebuiltMesocycle(uid, pushPullLegs);
      final second = await subject.startPrebuiltMesocycle(
        uid,
        PrebuiltCatalogue.instance.mesocycles.first,
      );

      expect(first.id, isNot(second.id));
      final macrocycles = await programs.watchMacrocycles(uid).first;
      expect(
        [for (final m in macrocycles) (m.mesocycleIds.single, m.status)],
        [
          (first.id, MacrocycleStatus.ended),
          (second.id, MacrocycleStatus.active),
        ],
      );
      expect(
        (await users.watchUser(uid).first)!.submittedActiveMesocycleId,
        second.id,
      );
      expect(await programs.watchMesocycles(uid).first, hasLength(2));

      final gym = await subject.saveGymProfile(
        newGymProfile(
          authorId: uid,
          name: 'Home',
          now: DateTime.utc(2026),
          weightUnit: null,
        ),
      );
      await subject.setFavouriteGymProfile(uid, gym.id);
      expect(
        [for (final g in await library.watchGymProfiles(uid).first) g.name],
        ['Home'],
      );
      expect(
        (await users.watchUser(uid).first)!.submittedFavouriteGymProfileId,
        gym.id,
      );
    });
  });
}
