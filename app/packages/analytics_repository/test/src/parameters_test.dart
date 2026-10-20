import 'package:analytics_repository/src/parameters.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Side { left }

void main() {
  group('clean', () {
    test('clips to the limit and replaces spaces with underscores', () {
      expect(clean('Workout Started Today', 15), 'Workout_Started');
      expect(clean('short', 40), 'short');
    });

    test('never splits a character', () {
      expect(clean('💪💪💪', 2), '💪💪');
    });
  });

  group('describe', () {
    test('turns values into text as the Swift convertToString does', () {
      expect(describe(null), isNull);
      expect(describe('a b'), 'a b');
      expect(describe(3), '3');
      expect(describe(2.5), '2.5');
      expect(describe(1.0), '1.0');
      expect(describe(true), 'true');
      expect(describe(_Side.left), 'left');
      expect(
        describe(DateTime.utc(2026, 10, 14, 21, 30)),
        '2026-10-14T21:30:00.000Z',
      );
      expect(describe(Uri.parse('https://x.y')), 'https://x.y');
    });

    test('sorts and joins a list, leaving out nulls', () {
      expect(describe(['pull', null, 'push', 3]), '3, pull, push');
      expect(describe(<Object?>[]), '');
    });
  });

  group('firebaseParameters', () {
    test('is empty for no parameters', () {
      expect(firebaseParameters(null), isEmpty);
    });

    test('keeps strings and numbers only', () {
      expect(
        firebaseParameters({
          'count': 3,
          'weight': 82.5,
          'name': 'Bench Press',
          'is_new_user': true,
          'is_premium': false,
          'side': _Side.left,
          'logged_at': DateTime.utc(2026, 10, 14),
          'muscles': ['triceps', 'chest'],
          'missing': null,
          'nested': {'a': 1},
        }),
        {
          'count': 3,
          'weight': 82.5,
          'name': 'Bench_Press',
          'is_new_user': 1,
          'is_premium': 0,
          'side': 'left',
          'logged_at': '2026-10-14T00:00:00.000Z',
          'muscles': 'chest,_triceps',
        },
      );
    });

    test('cleans keys to 40 characters and text to 100', () {
      final key = 'k' * 45;
      final value = 'v' * 120;
      expect(firebaseParameters({key: value}), {'k' * 40: 'v' * 100});
      expect(firebaseParameters({'a key': 1}), {'a_key': 1});
    });

    test('keeps the first 25 parameters', () {
      final parameters = firebaseParameters({
        for (var i = 0; i < 30; i++) 'p$i': i,
      });
      expect(parameters.length, 25);
      expect(parameters.keys.last, 'p24');
    });
  });

  group('mixpanelProperties', () {
    test('is empty for no parameters', () {
      expect(mixpanelProperties(null), isEmpty);
    });

    test('keeps what Mixpanel can send and drops the rest', () {
      final date = DateTime.utc(2026, 10, 14);
      final uri = Uri.parse('https://x.y');
      expect(
        mixpanelProperties({
          'name': 'Bench Press',
          'count': 3,
          'weight': 82.5,
          'is_new_user': true,
          'logged_at': date,
          'link': uri,
          'side': _Side.left,
          'muscles': ['chest', null, _Side.left, Object()],
          'missing': null,
          'other': Object(),
        }),
        {
          'name': 'Bench Press',
          'count': 3,
          'weight': 82.5,
          'is_new_user': true,
          'logged_at': date,
          'link': uri,
          'side': 'left',
          'muscles': ['chest', 'left'],
        },
      );
    });

    test('clips keys to 255 characters', () {
      expect(mixpanelProperties({'k' * 300: 1}), {'k' * 255: 1});
    });
  });
}
