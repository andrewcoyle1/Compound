import 'dart:typed_data';

import 'package:app_ui/app_ui.dart';
import 'package:auth_repository/auth_repository.dart';
import 'package:body_repository/body_repository.dart';
import 'package:compound/app/app.dart';
import 'package:compound/progress_photos/progress_photos.dart';
import 'package:compound/settings/account/view/edit_profile_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_repository/image_repository.dart';
import 'package:nutrition_repository/nutrition_repository.dart';
import 'package:program_repository/program_repository.dart';
import 'package:purchases_repository/purchases_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

import '../helpers/app_repositories.dart';

/// Every pick returns [photo], as the staging flavor's sample picker does.
class _Picker implements PhotoPicker {
  final photo = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

  @override
  Future<Uint8List?> pick(PhotoSource source, PhotoSize size) async => photo;

  @override
  Future<void> openSettings() async {}
}

// The whole app on the staging flavor's in-memory data, signed in as the
// sample user: Body Metrics' Photos row, adding a library photo and a camera
// photo, comparing two, deleting one; and changing the profile photo.
void main() {
  const uid = sampleUserId;
  final now = DateTime.now();
  late InMemoryImageRepository images;
  late InMemoryUserRepository users;

  Future<void> pumpAt(WidgetTester tester, String location) async {
    tester.view
      ..physicalSize = const Size(1290, 2796)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    images = InMemoryImageRepository();
    users = InMemoryUserRepository(
      users: {uid: sampleUser(now: now)},
      settings: {uid: sampleUserSettings(now: now)},
    );
    await tester.pumpWidget(
      App(
        socialRepository: emptySocialRepository(),
        coachRepository: silentCoachRepository(),
        programRepository: InMemoryProgramRepository(),
        trainingLibraryRepository: InMemoryTrainingLibraryRepository(),
        authRepository: InMemoryAuthRepository(
          user: InMemoryAuthRepository.sampleUser,
        ),
        userRepository: users,
        workoutSessionRepository: InMemoryWorkoutSessionRepository(
          sessions: const [],
        ),
        bodyRepository: InMemoryBodyRepository(
          measurements: sampleBodyMeasurements(uid: uid, now: now),
          progressPhotos: sampleProgressPhotos(uid: uid, now: now),
        ),
        nutritionRepository: InMemoryNutritionRepository(),
        imageRepository: images,
        photoPicker: _Picker(),
        purchasesRepository: FakePurchasesRepository(),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(location);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> add(WidgetTester tester, String item) async {
    await tap(tester, find.byTooltip('Add Photo').first);
    await tap(tester, find.text(item));
  }

  testWidgets('Body Metrics opens the photos; add, compare and delete', (
    tester,
  ) async {
    await pumpAt(tester, '/progress/body-metrics');

    await tester.scrollUntilVisible(
      find.text('Progress Photos'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tap(tester, find.text('Progress Photos'));
    expect(find.byType(ProgressPhotosView), findsOneWidget);
    expect(find.text('Select two photos to compare them.'), findsOneWidget);
    expect(find.text('Front'), findsNWidgets(2));

    // A library photo asks its pose.
    await add(tester, 'Choose from Library');
    expect(find.text('Which pose is this?'), findsOneWidget);
    await tap(tester, find.text('Side'));
    expect(find.text('Side'), findsOneWidget);
    expect(
      images.images.keys.single,
      startsWith('users/$uid/progress_photos/'),
    );

    // A camera photo was given its pose first.
    await add(tester, 'Take Back Photo');
    expect(find.text('Back'), findsOneWidget);
    expect(images.images, hasLength(2));

    // Compare is the screen's one action, waiting for two photos.
    AppCtaButton compareButton() => tester.widget<AppCtaButton>(
      find.widgetWithText(AppCtaButton, 'Compare'),
    );
    expect(compareButton().onPressed, isNull);

    // Two chosen: Compare opens them side by side, or with the slider.
    await tap(tester, find.text('Side'));
    await tap(tester, find.text('Back'));
    await tap(tester, find.text('Compare'));
    expect(find.byType(ProgressPhotoComparePage), findsOneWidget);
    expect(find.text('Side by Side'), findsOneWidget);
    await tap(tester, find.text('Slider'));
    expect(find.byType(Slider), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // One chosen (Back no longer): Delete, confirmed, removes it and its
    // image.
    await tap(tester, find.text('Back'));
    await tap(tester, find.byTooltip('Delete'));
    await tap(tester, find.widgetWithText(TextButton, 'Delete'));
    expect(find.text('Side'), findsNothing);
    expect(images.images, hasLength(1));
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('with no photos, the empty screen offers the same choices', (
    tester,
  ) async {
    await pumpAt(tester, '/progress/body-metrics/photos');
    // Delete the samples.
    for (var i = 0; i < 2; i++) {
      await tap(tester, find.text('Front').first);
      await tap(tester, find.byTooltip('Delete'));
      await tap(tester, find.widgetWithText(TextButton, 'Delete'));
    }
    expect(find.text('No Progress Photos'), findsOneWidget);

    await tap(tester, find.text('Add Photo'));
    await tap(tester, find.text('Take Front Photo'));
    expect(find.text('No Progress Photos'), findsNothing);
    expect(find.text('Front'), findsOneWidget);
  });

  testWidgets('Edit Profile uploads a new profile photo on Save', (
    tester,
  ) async {
    await pumpAt(tester, '/profile/${EditProfilePage.path}');

    // The sample user has their sign-in account's picture.
    await tap(tester, find.byTooltip('Change profile photo'));
    await tap(tester, find.byIcon(AppSymbols.selected));

    expect(images.images.keys, ['users/$uid/profile']);
    final profile = await users.watchUser(uid).first;
    expect(profile!.submittedProfileImage, startsWith('data:image/jpeg'));
  });
}
