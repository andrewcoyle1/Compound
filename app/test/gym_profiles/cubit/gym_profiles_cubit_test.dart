import 'package:compound/gym_profiles/cubit/gym_profiles_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

import '../../onboarding/cubit/helpers.dart';

class _MockLibrary extends Mock implements TrainingLibraryRepository;

/// Swift `GymProfilesListPresenterTests`, for the writes: deleting and
/// favouriting. What the list shows is the page's widget test.
void main() {
  final gym = newGymProfile(
    authorId: 'user-1',
    name: 'Commercial',
    now: DateTime.utc(2026, 10, 16),
    weightUnit: null,
    newId: () => 'a',
  );
  late _MockLibrary library;
  late MockTrainingSetupService setup;
  late RecordingAnalytics analytics;

  setUp(() {
    library = _MockLibrary();
    setup = MockTrainingSetupService();
    analytics = RecordingAnalytics();
    when(() => library.deleteGymProfile(any(), any())).thenAnswer((_) async {});
    when(() => setup.setFavouriteGymProfile(any(), any()))
        .thenAnswer((_) async {});
  });

  GymProfilesCubit build() => GymProfilesCubit(
    uid: 'user-1',
    library: library,
    setup: setup,
    analytics: analytics.repository,
  );

  test('appearing is tracked as a screen view, and leaving', () async {
    final cubit = build();
    expect(analytics.names, ['GymProfilesView_Appear']);
    await cubit.close();
    expect(analytics.names.last, 'GymProfilesView_Disappear');
  });

  test('deleting a gym deletes that gym', () async {
    final cubit = build();
    await cubit.delete(gym);
    verify(() => library.deleteGymProfile('user-1', 'a')).called(1);
    expect(analytics.names, contains('GymProfilesView_DeleteProfile_Success'));
    expect(cubit.state, GymProfilesStatus.idle);
  });

  test('a failed delete is recorded as a failure and reported', () async {
    when(() => library.deleteGymProfile(any(), any()))
        .thenThrow(Exception('offline'));
    final cubit = build();
    await cubit.delete(gym);
    expect(analytics.names, contains('GymProfilesView_DeleteProfile_Fail'));
    expect(
      analytics.names,
      isNot(contains('GymProfilesView_DeleteProfile_Success')),
    );
    expect(cubit.state, GymProfilesStatus.deleteFailure);
  });

  test('favouriting a gym records it against the user', () async {
    final cubit = build();
    await cubit.favourite(gym);
    verify(() => setup.setFavouriteGymProfile('user-1', 'a')).called(1);
    expect(
      analytics.names,
      contains('GymProfilesView_FavouriteGymProfile_Success'),
    );
  });

  test('a failed favourite is recorded as a failure and reported', () async {
    when(() => setup.setFavouriteGymProfile(any(), any()))
        .thenThrow(Exception('offline'));
    final cubit = build();
    await cubit.favourite(gym);
    expect(
      analytics.names,
      contains('GymProfilesView_FavouriteGymProfile_Fail'),
    );
    expect(cubit.state, GymProfilesStatus.favouriteFailure);
  });
}
