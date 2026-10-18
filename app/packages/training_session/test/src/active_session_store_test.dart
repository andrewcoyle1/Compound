import 'dart:convert';
import 'dart:io';

import 'package:compound_models/compound_models.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_rules/training_rules.dart' as r;
import 'package:training_session/training_session.dart';

import '../helpers/fixtures.dart';

final _full = ActiveSessionState(
  session: session([
    exercise('e1', sets: [set('s1', done: true, rpe: 8), set('s2')]),
  ]),
  cardExerciseId: 'e1',
  restEnd: DateTime.utc(2026, 10, 15, 9, 1, 30),
  restStartedAt: DateTime.utc(2026, 10, 15, 9),
  pausedAt: DateTime.utc(2026, 10, 15, 9, 5),
  pausedSeconds: 42.5,
  customRestSeconds: const {'s2': 120},
  progressionBaseline: const {
    's1': r.SuggestedSet(weightKg: 80, reps: 8),
    's2': r.SuggestedSet.none,
  },
  acknowledgedNoteTemplateIds: const {'template-e1'},
  lastSeenSetCompletion: DateTime.utc(2026, 10, 15, 9, 2),
  saved: SavedFinish.refused,
);

void _expectSame(ActiveSessionState? read, ActiveSessionState expected) {
  expect(read, isNotNull);
  expect(jsonEncode(read!.toJson()), jsonEncode(expected.toJson()));
  expect(
    m.firestoreToTaggedJson(read.session.toFirestore()),
    m.firestoreToTaggedJson(expected.session.toFirestore()),
  );
  expect(read.restEnd, expected.restEnd);
  expect(read.pausedSeconds, expected.pausedSeconds);
  expect(read.customRestSeconds, expected.customRestSeconds);
  expect(read.progressionBaseline, expected.progressionBaseline);
  expect(
    read.acknowledgedNoteTemplateIds,
    expected.acknowledgedNoteTemplateIds,
  );
  expect(read.saved, expected.saved);
}

void main() {
  group('ActiveSessionState', () {
    test('round-trips through JSON, full and bare', () {
      _expectSame(ActiveSessionState.fromJson(_full.toJson()), _full);
      final bare = ActiveSessionState(session: session(const []));
      final read = ActiveSessionState.fromJson(bare.toJson());
      _expectSame(read, bare);
      expect(read.restEnd, isNull);
      expect(read.cardExerciseId, isNull);
    });

    test('refuses what this build did not write', () {
      for (final json in <Map<String, Object?>>[
        {..._full.toJson(), 'version': 2},
        {..._full.toJson(), 'rest_end': 'yesterday'},
        {..._full.toJson(), 'paused_seconds': null},
        {..._full.toJson(), 'session': <String, Object?>{}},
        {..._full.toJson(), 'saved': 'sent'},
        {..._full.toJson(), 'saved': 1},
      ]) {
        expect(() => ActiveSessionState.fromJson(json), throwsFormatException);
      }
    });
  });

  group('InMemoryActiveSessionStore', () {
    test('keeps a copy, and forgets it', () async {
      final store = InMemoryActiveSessionStore();
      expect(await store.load(), isNull);

      await store.save(_full);
      _expectSame(await store.load(), _full);

      await store.clear();
      expect(await store.load(), isNull);
    });
  });

  group('FileActiveSessionStore', () {
    late Directory directory;
    late File file;
    late FileActiveSessionStore store;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('active_session');
      file = File('${directory.path}/workout/active.json');
      store = FileActiveSessionStore(file);
    });

    tearDown(() => directory.deleteSync(recursive: true));

    test('survives a new store over the same file, as after a kill', () async {
      expect(await store.load(), isNull);

      await store.save(_full);
      _expectSame(await FileActiveSessionStore(file).load(), _full);
      expect(File('${file.path}.tmp').existsSync(), isFalse);

      await store.clear();
      expect(await store.load(), isNull);
      await store.clear();
    });

    test('moves a file it cannot read aside rather than losing it', () async {
      for (final text in ['{not json', '[1, 2]', '{"version": 1}']) {
        file
          ..createSync(recursive: true)
          ..writeAsStringSync(text);

        expect(await store.load(), isNull);
        expect(file.existsSync(), isFalse);
        expect(store.unreadable.readAsStringSync(), text);
      }
    });
  });
}
