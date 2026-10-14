import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

void main() {
  group('taggedJsonToFirestore', () {
    test('turns tagged timestamps into UTC DateTimes at any depth', () {
      expect(
        taggedJsonToFirestore({
          'at': {timestampTag: '2026-01-02T03:04:05.123Z'},
          'nested': {
            'list': [
              {timestampTag: '2026-01-02T03:04:05.000Z'},
              1,
            ],
          },
          'plain': {timestampTag: 'x', 'other': 1},
        }),
        {
          'at': DateTime.utc(2026, 1, 2, 3, 4, 5, 123),
          'nested': {
            'list': [DateTime.utc(2026, 1, 2, 3, 4, 5), 1],
          },
          'plain': {timestampTag: 'x', 'other': 1},
        },
      );
    });

    test('turns tagged doubles into NaN and the infinities', () {
      final firestore = taggedJsonToFirestore({
        'nan': {doubleTag: 'NaN'},
        'inf': {doubleTag: 'Infinity'},
        'negative': {doubleTag: '-Infinity'},
        'other': {doubleTag: '1.5'},
      });
      expect((firestore['nan']! as double).isNaN, isTrue);
      expect(firestore['inf'], double.infinity);
      expect(firestore['negative'], double.negativeInfinity);
      expect(firestore['other'], {doubleTag: '1.5'});
    });
  });

  group('firestoreToTaggedJson', () {
    test('tags DateTimes at any depth and keeps JSON values', () {
      expect(
        firestoreToTaggedJson({
          'at': DateTime.utc(2026, 1, 2, 3, 4, 5, 123),
          'nested': {
            'list': [null, true, 1, 1.5, 'a'],
          },
        }),
        {
          'at': {timestampTag: '2026-01-02T03:04:05.123Z'},
          'nested': {
            'list': [null, true, 1, 1.5, 'a'],
          },
        },
      );
    });

    test('throws on a value Firestore does not hold as JSON', () {
      expect(() => firestoreToTaggedJson({'x': Object()}), throwsArgumentError);
    });
  });

  group('formatContractTimestamp', () {
    test('rounds to the millisecond in UTC with three digits', () {
      expect(
        formatContractTimestamp(DateTime.utc(2026, 1, 2, 3, 4, 5, 0, 600)),
        '2026-01-02T03:04:05.001Z',
      );
      expect(
        formatContractTimestamp(DateTime.utc(2026, 1, 2, 3, 4, 5, 999, 500)),
        '2026-01-02T03:04:06.000Z',
      );
    });
  });
}
