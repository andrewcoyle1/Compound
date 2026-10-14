import 'package:bloc_test/bloc_test.dart';
import 'package:compound/profile/profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  const user = UserModel(userId: 'uid', displayName: 'Ada');
  late UserRepository userRepository;

  setUp(() {
    userRepository = MockUserRepository();
  });

  group(ProfileBloc, () {
    test('starts loading', () {
      expect(
        ProfileBloc(userRepository: userRepository, uid: 'uid').state,
        const ProfileLoading(),
      );
    });

    blocTest<ProfileBloc, ProfileState>(
      'follows the profile, including its disappearing',
      setUp: () =>
          when(() => userRepository.watchUser('uid'))
              .thenAnswer((_) => Stream.fromIterable([user, null])),
      build: () => ProfileBloc(userRepository: userRepository, uid: 'uid'),
      act: (bloc) => bloc.add(const ProfileSubscriptionRequested()),
      expect: () => const [ProfileLoaded(user), ProfileUnavailable()],
    );

    blocTest<ProfileBloc, ProfileState>(
      'is unavailable when the stream fails',
      setUp: () =>
          when(() => userRepository.watchUser('uid'))
              .thenAnswer((_) => Stream.error(Exception('offline'))),
      build: () => ProfileBloc(userRepository: userRepository, uid: 'uid'),
      act: (bloc) => bloc.add(const ProfileSubscriptionRequested()),
      expect: () => const [ProfileUnavailable()],
    );
  });
}
