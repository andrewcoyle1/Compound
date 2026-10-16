import 'dart:typed_data';

import 'package:ai_repository/ai_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_repository/image_repository.dart';

/// The AI callables, answering [json] as the model's `result` (or failing
/// as `unavailable` when [fails]), and remembering every call.
class FakeAi {
  String json = '{"items": []}';
  bool fails = false;
  final calls = <(String, Map<String, Object?>)>[];

  late final repository = AiRepository(
    callFunction: (name, data) async {
      calls.add((name, data));
      if (fails) {
        throw FirebaseFunctionsException(code: 'unavailable', message: '');
      }
      return {'result': json};
    },
    now: () => DateTime.utc(2026, 10, 16),
    newId: () => 'new-id',
  );
}

/// A camera that returns [photo] (null for a cancel) or throws [error],
/// remembering each pick and each time Settings is opened.
class FakePhotoPicker implements PhotoPicker {
  Uint8List? photo = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
  Exception? error;
  final picks = <(PhotoSource, PhotoSize)>[];
  int settingsOpened = 0;

  @override
  Future<Uint8List?> pick(PhotoSource source, PhotoSize size) async {
    picks.add((source, size));
    if (error case final error?) throw error;
    return photo;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}
