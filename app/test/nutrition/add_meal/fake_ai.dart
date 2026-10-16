import 'package:ai_repository/ai_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';

export '../../helpers/photos.dart' show FakePhotoPicker;

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
