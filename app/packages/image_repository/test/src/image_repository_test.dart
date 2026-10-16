import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_repository/image_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FirebaseStorage;

class _MockReference extends Mock implements Reference;

class _MockImagePicker extends Mock implements ImagePicker;

class _Snapshot extends Fake implements TaskSnapshot;

/// An upload that has finished (or failed with [error]).
class _Upload extends Fake implements UploadTask {
  new([this.error]);

  final Object? error;

  @override
  Future<R> then<R>(
    FutureOr<R> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) {
    final future = error == null
        ? Future<TaskSnapshot>.value(_Snapshot())
        : Future<TaskSnapshot>.error(error!);
    return future.then(onValue, onError: onError);
  }
}

void main() {
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(SettableMetadata());
    registerFallbackValue(ImageSource.camera);
  });

  group('FirebaseImageRepository', () {
    late _MockStorage storage;
    late _MockReference reference;

    setUp(() {
      storage = _MockStorage();
      reference = _MockReference();
      when(() => storage.ref(any())).thenReturn(reference);
    });

    test('uploads a JPEG at the path and returns its download URL', () async {
      when(() => reference.putData(any(), any())).thenAnswer((_) => _Upload());
      when(reference.getDownloadURL)
          .thenAnswer((_) async => 'https://example.com/p.jpg');

      final url = await FirebaseImageRepository(storage: storage)
          .upload(jpeg, 'users/u1/profile');

      expect(url, 'https://example.com/p.jpg');
      verify(() => storage.ref('users/u1/profile')).called(1);
      verify(() => storage.setMaxUploadRetryTime(const Duration(seconds: 15)))
          .called(1);
      final metadata =
          verify(() => reference.putData(jpeg, captureAny())).captured.single
              as SettableMetadata;
      expect(metadata.contentType, 'image/jpeg');
    });

    test('a refused upload fails and asks for no URL', () async {
      when(() => reference.putData(any(), any())).thenAnswer(
        (_) => _Upload(
          FirebaseException(plugin: 'storage', code: 'retry-limit-exceeded'),
        ),
      );

      await expectLater(
        FirebaseImageRepository(
          storage: storage,
          maxUploadRetryTime: const Duration(seconds: 2),
        ).upload(jpeg, 'users/u1/profile'),
        throwsA(isA<FirebaseException>()),
      );
      verify(() => storage.setMaxUploadRetryTime(const Duration(seconds: 2)))
          .called(1);
      verifyNever(reference.getDownloadURL);
    });

    test('deletes the image at the path', () async {
      when(reference.delete).thenAnswer((_) async {});

      await FirebaseImageRepository(storage: storage)
          .delete('users/u1/progress_photos/p1.jpg');

      verify(() => storage.ref('users/u1/progress_photos/p1.jpg')).called(1);
      verify(reference.delete).called(1);
    });
  });

  group('InMemoryImageRepository', () {
    test('keeps the image and returns it as a data URI', () async {
      final repository = InMemoryImageRepository();

      final url = await repository.upload(jpeg, 'users/u1/profile');

      expect(repository.images['users/u1/profile'], jpeg);
      final data = Uri.parse(url).data!;
      expect(data.mimeType, 'image/jpeg');
      expect(data.contentAsBytes(), jpeg);

      await repository.delete('users/u1/profile');
      expect(repository.images, isEmpty);
    });
  });

  group('PhotoSize', () {
    test("matches Swift's sizes", () {
      expect(PhotoSize.standard.maxDimension, 1280);
      expect(PhotoSize.standard.quality, 70);
      expect(PhotoSize.progressPhoto.maxDimension, 1600);
      expect(PhotoSize.progressPhoto.quality, 80);
    });
  });

  group('DevicePhotoPicker', () {
    late _MockImagePicker picker;

    setUp(() => picker = _MockImagePicker());

    void answer(XFile? file) => when(
      () => picker.pickImage(
        source: any(named: 'source'),
        maxWidth: any(named: 'maxWidth'),
        maxHeight: any(named: 'maxHeight'),
        imageQuality: any(named: 'imageQuality'),
        requestFullMetadata: any(named: 'requestFullMetadata'),
      ),
    ).thenAnswer((_) async => file);

    test('takes a camera photo at the size, without full metadata', () async {
      answer(XFile.fromData(jpeg));

      final bytes = await DevicePhotoPicker(picker: picker)
          .pick(PhotoSource.camera, PhotoSize.progressPhoto);

      expect(bytes, jpeg);
      verify(
        () => picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
          requestFullMetadata: false,
        ),
      ).called(1);
    });

    test('picks from the library, and a cancel is null', () async {
      answer(null);

      final bytes = await DevicePhotoPicker(picker: picker)
          .pick(PhotoSource.library, PhotoSize.standard);

      expect(bytes, isNull);
      verify(
        () => picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1280,
          maxHeight: 1280,
          imageQuality: 70,
          requestFullMetadata: false,
        ),
      ).called(1);
    });

    test('defaults to the platform picker', () {
      expect(DevicePhotoPicker(), isA<PhotoPicker>());
    });
  });

  group('SamplePhotoPicker', () {
    test('returns the sample from either source', () async {
      final picker = SamplePhotoPicker(() async => jpeg);
      expect(await picker.pick(PhotoSource.camera, PhotoSize.standard), jpeg);
      expect(
        await picker.pick(PhotoSource.library, PhotoSize.progressPhoto),
        jpeg,
      );
    });
  });
}
