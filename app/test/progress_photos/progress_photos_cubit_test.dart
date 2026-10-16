import 'dart:typed_data';

import 'package:app_ui/app_ui.dart' show AppWeightUnit;
import 'package:body_repository/body_repository.dart';
import 'package:compound/progress_photos/progress_photos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_repository/image_repository.dart';

import '../helpers/analytics_recorder.dart';

const _uid = 'me';

/// Returns [photo], or throws [error], and records what was asked.
class _Picker implements PhotoPicker {
  Uint8List? photo = Uint8List.fromList([1, 2, 3]);
  Exception? error;
  final picks = <(PhotoSource, PhotoSize)>[];

  @override
  Future<Uint8List?> pick(PhotoSource source, PhotoSize size) async {
    picks.add((source, size));
    if (error case final error?) throw error;
    return photo;
  }
}

class _FailingUpload extends InMemoryImageRepository {
  @override
  Future<String> upload(Uint8List jpeg, String path) =>
      Future.error(Exception('retry-limit-exceeded'));
}

class _FailingImageDelete extends InMemoryImageRepository {
  @override
  Future<void> delete(String path) => Future.error(Exception('not-found'));
}

/// Refuses to start a photo save or delete, as an encoder error would.
class _FailingBody extends InMemoryBodyRepository {
  new({super.progressPhotos, super.measurements});

  bool failSave = false;
  bool failDelete = false;

  @override
  Future<void> saveProgressPhoto(ProgressPhotoModel photo) => failSave
      ? Future.error(Exception('refused'))
      : super.saveProgressPhoto(photo);

  @override
  Future<void> deleteProgressPhoto(String uid, String photoId) => failDelete
      ? Future.error(Exception('refused'))
      : super.deleteProgressPhoto(uid, photoId);
}

ProgressPhotoModel _photo(String id, DateTime date) => ProgressPhotoModel(
  id: id,
  authorId: _uid,
  date: date,
  pose: ProgressPhotoPose.front,
  storagePath: ProgressPhotoModel.storagePathFor(_uid, id),
  imageUrl: 'assets/exercises/BarbellSquat.webp',
);

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 9);
  final lastMonth = DateTime(now.year, now.month - 1, now.day, 9);
  final lastWeek = DateTime(now.year, now.month, now.day - 7, 9);

  late _FailingBody body;
  late InMemoryImageRepository images;
  late _Picker picker;
  late AnalyticsRecorder analytics;

  setUp(() {
    body = _FailingBody(
      progressPhotos: [
        _photo('old', lastMonth),
        _photo('new', today),
        _photo('mid', lastWeek),
      ],
      measurements: [
        BodyMeasurementEntry(
          id: 'w1',
          authorId: _uid,
          weightKg: 80.4,
          date: lastMonth,
          source: WeightSource.manual,
          dateCreated: lastMonth,
        ),
        BodyMeasurementEntry(
          id: 'w2',
          authorId: _uid,
          weightKg: 79.6,
          date: lastWeek,
          source: WeightSource.manual,
          dateCreated: lastWeek,
        ),
        BodyMeasurementEntry(
          id: 'tape',
          authorId: _uid,
          waistCircumference: 84,
          date: today,
          source: WeightSource.manual,
          dateCreated: today,
        ),
      ],
    );
    images = InMemoryImageRepository();
    picker = _Picker();
    analytics = AnalyticsRecorder();
  });

  ProgressPhotosCubit build({ImageRepository? imageRepository}) =>
      ProgressPhotosCubit(
        uid: _uid,
        body: body,
        images: imageRepository ?? images,
        picker: picker,
        analytics: analytics,
        weightUnit: AppWeightUnit.pounds,
        clock: () => today,
      );

  Future<ProgressPhotosCubit> loaded({ImageRepository? imageRepository}) async {
    final cubit = build(imageRepository: imageRepository);
    await pumpEventQueue();
    return cubit;
  }

  test('lists the photos newest first, grouped by day', () async {
    final cubit = await loaded();
    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.weightUnit, AppWeightUnit.pounds);
    expect(cubit.state.photos.map((photo) => photo.id), ['new', 'mid', 'old']);
    expect(cubit.state.sections.map((section) => section.$2.single.id), [
      'new',
      'mid',
      'old',
    ]);
    expect(analytics.names, ['ProgressPhotosView_Appear']);
    await cubit.close();
    expect(analytics.names.last, 'ProgressPhotosView_Disappear');
  });

  group('selecting', () {
    test('toggles, and a third choice drops the earliest', () async {
      final cubit = await loaded();
      final photos = {for (final photo in cubit.state.photos) photo.id: photo};

      cubit.photoPressed(photos['new']!);
      expect(cubit.state.selectedForDelete?.id, 'new');
      expect(cubit.state.comparePair, isNull);

      cubit
        ..photoPressed(photos['old']!)
        ..photoPressed(photos['mid']!);
      expect(cubit.state.selectedIds, ['old', 'mid']);
      expect(cubit.state.selectedForDelete, isNull);
      expect(cubit.state.isSelected(photos['new']!), isFalse);

      cubit.photoPressed(photos['old']!);
      expect(cubit.state.selectedIds, ['mid']);
    });

    test('compares the older on the left, whatever the order', () async {
      final cubit = await loaded();
      final photos = {for (final photo in cubit.state.photos) photo.id: photo};
      cubit
        ..photoPressed(photos['new']!)
        ..photoPressed(photos['old']!);

      final pair = cubit.state.comparePair!;
      expect((pair.$1.id, pair.$2.id), ('old', 'new'));

      cubit.comparePressed();
      expect(analytics.names.last, 'ProgressPhotosView_Compare');
    });

    test('a photo deleted elsewhere is no longer chosen', () async {
      final cubit = await loaded();
      cubit.photoPressed(cubit.state.photos.first);
      await body.deleteProgressPhoto(_uid, 'new');
      await pumpEventQueue();
      expect(cubit.state.selectedIds, isEmpty);
    });
  });

  group('adding', () {
    test('a camera photo uploads at the progress size and saves with the '
        'pose and the latest weight', () async {
      final cubit = await loaded();

      await cubit.cameraPressed(ProgressPhotoPose.side);
      await pumpEventQueue();

      expect(picker.picks, [(PhotoSource.camera, PhotoSize.progressPhoto)]);
      final added = cubit.state.photos.firstWhere(
        (photo) => !{'old', 'mid', 'new'}.contains(photo.id),
      );
      expect(added.pose, ProgressPhotoPose.side);
      expect(added.date, today);
      expect(added.weightKg, 79.6);
      expect(
        added.storagePath,
        ProgressPhotoModel.storagePathFor(_uid, added.id),
      );
      expect(images.images[added.storagePath], picker.photo);
      expect(Uri.parse(added.imageUrl!).data!.contentAsBytes(), picker.photo);
      expect(cubit.state.isUploading, isFalse);
      expect(
        analytics.names,
        containsAllInOrder([
          'ProgressPhotosView_Add_Start',
          'ProgressPhotosView_Add_Success',
        ]),
      );
      expect(analytics.parameters('ProgressPhotosView_Add_Success'), {
        'pose': 'side',
      });
    });

    test('a library photo waits for its pose', () async {
      final cubit = await loaded();

      await cubit.libraryPressed();
      expect(picker.picks.single.$1, PhotoSource.library);
      expect(cubit.state.pendingImage, picker.photo);
      expect(images.images, isEmpty);

      await cubit.poseSelected(ProgressPhotoPose.back);
      await pumpEventQueue();

      expect(cubit.state.pendingImage, isNull);
      expect(cubit.state.photos, hasLength(4));
      expect(
        cubit.state.photos.where((p) => p.pose == ProgressPhotoPose.back),
        hasLength(1),
      );
    });

    test('a dismissed pose question drops the photo', () async {
      final cubit = await loaded();
      await cubit.libraryPressed();
      cubit.poseCancelled();
      await cubit.poseSelected(ProgressPhotoPose.front);
      expect(cubit.state.pendingImage, isNull);
      expect(images.images, isEmpty);
    });

    test('a cancelled pick does nothing', () async {
      picker.photo = null;
      final cubit = await loaded();
      await cubit.cameraPressed(ProgressPhotoPose.front);
      await cubit.libraryPressed();
      expect(cubit.state.pendingImage, isNull);
      expect(images.images, isEmpty);
    });

    test('a photo that cannot be read says so', () async {
      picker.error = Exception('camera unavailable');
      final cubit = await loaded();
      await cubit.cameraPressed(ProgressPhotoPose.front);
      expect(cubit.state.loadFailures, 1);
      expect(analytics.names.last, 'ProgressPhotosView_LoadLibraryPhoto_Fail');
    });

    test('a failed upload saves nothing and says so', () async {
      final cubit = await loaded(imageRepository: _FailingUpload());
      await cubit.cameraPressed(ProgressPhotoPose.front);
      expect(cubit.state.photos, hasLength(3));
      expect(cubit.state.addFailures, 1);
      expect(cubit.state.isUploading, isFalse);
      expect(analytics.names.last, 'ProgressPhotosView_Add_Fail');
    });

    test('a save that cannot start removes the uploaded image', () async {
      body.failSave = true;
      final cubit = await loaded();
      await cubit.cameraPressed(ProgressPhotoPose.front);
      expect(images.images, isEmpty);
      expect(cubit.state.addFailures, 1);
    });

    test('without a weight logged, the photo has none', () async {
      body = _FailingBody();
      final cubit = await loaded();
      await cubit.cameraPressed(ProgressPhotoPose.front);
      await pumpEventQueue();
      expect(cubit.state.photos.single.weightKg, isNull);
    });
  });

  group('deleting', () {
    test('removes the document, then the image', () async {
      final cubit = await loaded();
      await cubit.cameraPressed(ProgressPhotoPose.front);
      await pumpEventQueue();
      final added = cubit.state.photos.firstWhere(
        (photo) => images.images.containsKey(photo.storagePath),
      );
      cubit.photoPressed(added);

      await cubit.deleteConfirmed(added);
      await pumpEventQueue();

      expect(cubit.state.photos.map((photo) => photo.id), [
        'new',
        'mid',
        'old',
      ]);
      expect(cubit.state.selectedIds, isEmpty);
      expect(images.images, isEmpty);
      expect(analytics.names.last, 'ProgressPhotosView_Delete_Success');
    });

    test('a failed image delete is ignored', () async {
      final cubit = await loaded(imageRepository: _FailingImageDelete());
      await cubit.deleteConfirmed(cubit.state.photos.first);
      await pumpEventQueue();
      expect(cubit.state.photos, hasLength(2));
      expect(cubit.state.deleteFailures, 0);
    });

    test('a delete that cannot start says so', () async {
      body.failDelete = true;
      final cubit = await loaded();
      await cubit.deleteConfirmed(cubit.state.photos.first);
      expect(cubit.state.photos, hasLength(3));
      expect(cubit.state.deleteFailures, 1);
      expect(analytics.names.last, 'ProgressPhotosView_Delete_Fail');
    });
  });
}
