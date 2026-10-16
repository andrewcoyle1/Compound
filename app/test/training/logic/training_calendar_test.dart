import 'package:compound/training/logic/training_calendar.dart';
import 'package:compound/widgets/calendar/calendar.dart';
import 'package:compound_models/compound_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Swift's `TrainingHomePresenterTests` calendar cases, case for case.
WorkoutSessionModel trainingSession(
  String id, {
  required DateTime on,
  bool finished = true,
  bool isRestDay = false,
  String? mesocycleId,
}) => WorkoutSessionModel(
  id: id,
  authorId: 'me',
  name: 'Workout $id',
  mesocycleId: mesocycleId,
  dateCreated: on,
  dateModified: on,
  endedAt: finished ? on.add(const Duration(hours: 1)) : null,
  isRestDay: isRestDay,
  exercises: const [],
);

void main() {
  DateTime march(int day, [int hour = 9]) => DateTime(2026, 3, day, hour);

  Mesocycle mesocycle(String id, String colour) {
    final base = fixtureMesocycle(id, const []);
    return Mesocycle(
      id: id,
      authorId: base.authorId,
      name: id,
      icon: base.icon,
      colour: colour,
      workoutTemplates: const [],
      dateCreated: base.dateCreated,
      dateModified: base.dateModified,
    );
  }

  group('loggedWorkoutMarkersByDay', () {
    test('two workouts on one day are one marker', () {
      final markers = loggedWorkoutMarkersByDay([
        trainingSession('a', on: march(11, 7)),
        trainingSession('b', on: march(11, 19)),
      ], const []);
      expect(markers, {
        '2026-03-11': const SessionsMarker([null, null]),
      });
    });

    test('separate days get separate markers', () {
      final markers = loggedWorkoutMarkersByDay([
        trainingSession('a', on: march(11)),
        trainingSession('b', on: march(13)),
      ], const []);
      expect(markers['2026-03-11'], const SessionsMarker([null]));
      expect(markers['2026-03-13'], const SessionsMarker([null]));
    });

    test('a workout still running is not marked', () {
      expect(
        loggedWorkoutMarkersByDay([
          trainingSession('a', on: march(11), finished: false),
        ], const []),
        isEmpty,
      );
    });

    test('rest days are not marked', () {
      expect(
        loggedWorkoutMarkersByDay([
          trainingSession('a', on: march(11), isRestDay: true),
          trainingSession('b', on: march(15), isRestDay: true),
        ], const []),
        isEmpty,
      );
    });

    test("each workout wears its mesocycle's colour", () {
      final markers = loggedWorkoutMarkersByDay(
        [
          trainingSession('s', on: march(11, 19), mesocycleId: 'strength'),
          trainingSession('h', on: march(11, 7), mesocycleId: 'hypertrophy'),
          trainingSession('n', on: march(11, 12)),
          trainingSession('d', on: march(11, 21), mesocycleId: 'deleted'),
        ],
        [
          mesocycle('hypertrophy', '#0000FF'),
          mesocycle('strength', '#FF9500'),
          // The first of two with one id wins.
          mesocycle('strength', '#000000'),
        ],
      );
      expect(
        markers['2026-03-11'],
        const SessionsMarker(['#0000FF', null, '#FF9500', null]),
      );
    });
  });

  group('loggedWorkoutsOn', () {
    final sessions = [
      trainingSession('late', on: march(11, 19)),
      trainingSession('early', on: march(11, 7)),
      trainingSession('running', on: march(11, 8), finished: false),
      trainingSession('rest', on: march(11), isRestDay: true),
      trainingSession('other', on: march(12)),
    ];

    test("are the day's finished workouts, earliest first", () {
      expect(
        [
          for (final s in loggedWorkoutsOn(sessions, DateTime(2026, 3, 11)))
            s.id,
        ],
        ['early', 'late'],
      );
      expect(loggedWorkoutsOn(sessions, DateTime(2026, 3, 13)), isEmpty);
    });
  });
}
