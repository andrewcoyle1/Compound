import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_repository/image_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FirebaseStorage;

class _MockReference extends Mock implements Reference;

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
}
