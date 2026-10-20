import 'package:flutter_test/flutter_test.dart';
import 'package:workout_session_repository/workout_session_repository.dart';

void main() {
  group(InMemoryWorkoutSessionRepository, () {
    final created = DateTime.utc(2026, 10, 12);
    WorkoutSessionModel session(String id, String authorId) =>
        WorkoutSessionModel(
          id: id,
          authorId: authorId,
          name: id,
          dateCreated: created,
          dateModified: created,
          exercises: const [],
        );

    late InMemoryWorkoutSessionRepository subject;

    setUp(() {
      subject = InMemoryWorkoutSessionRepository(
        sessions: [session('a', 'me'), session('b', 'you'), session('c', 'me')],
      );
    });

    test('watchSessions emits only the sessions the user authored', () {
      expect(
        subject
            .watchSessions('me')
            .map((sessions) => [for (final s in sessions) s.id]),
        emits(['a', 'c']),
      );
    });

    test(
      'saveSessionConfirmed stores at once, and the server has it',
      () async {
        final write = await subject.saveSessionConfirmed(
          'me',
          session('d', 'me'),
        );
        await expectLater(write.confirmed, completes);
        expect(await subject.sessionOnServer('me', 'd'), isTrue);
        expect(await subject.sessionOnServer('me', 'b'), isFalse);
      },
    );

    group('session', () {
      test("returns the user's session with that id", () async {
        expect((await subject.session('me', 'c'))?.id, 'c');
      });

      test("returns null for another user's session or a missing id", () async {
        expect(await subject.session('me', 'b'), isNull);
        expect(await subject.session('me', 'z'), isNull);
      });
    });
  });
}
