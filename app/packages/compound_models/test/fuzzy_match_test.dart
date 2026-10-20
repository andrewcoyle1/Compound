import 'package:compound_models/compound_models.dart';
import 'package:test/test.dart';

/// A library item: a name, then other names, then a description.
typedef _Item = (String name, List<String?> others, String? description);

List<Iterable<String?>> _fields(_Item item) => [
  [item.$1],
  item.$2,
  [item.$3],
];

const _library = <_Item>[
  ('Barbell Bench Press', ['Flat Bench'], 'Lying on a bench, press the bar.'),
  ('Barbell Squat', ['Back Squat'], null),
  ('Chicken Breast', [], 'Grilled, skinless.'),
  ('Chickpeas', [], null),
  ('Crème Fraîche', [], 'Cultured cream.'),
  ('Dumbbell Curl', [null, ''], 'Curl a dumbbell.'),
  ('Kitchen Roll', [], 'Not food.'),
  ('Machine Chest Press', ['Seated Press'], 'Targets the chest.'),
  ('Pull-Up', ['Chin-Up'], 'Hang from a bar and pull.'),
  ('Romanian Deadlift', ['RDL'], 'Hinge at the hips.'),
  ('Seated Row', [], 'Pull the handle to the chest.'),
];

List<String> _search(String query, {bool anyWord = false}) => [
  for (final item in FuzzyMatch.search(
    _library,
    query,
    _fields,
    anyWord: anyWord,
  ))
    item.$1,
];

void main() {
  group(FuzzyMatch, () {
    test('normalises case, accents and punctuation', () {
      expect(FuzzyMatch.normalised('  Crème Brûlée! '), 'creme brulee');
      expect(FuzzyMatch.normalised('Pull-Up (Wide)'), 'pull up wide');
      expect(FuzzyMatch.isSearching(' !? '), isFalse);
      expect(FuzzyMatch.isSearching('a'), isTrue);
    });

    test('a blank query keeps every item in its order', () {
      expect(_search(''), [for (final item in _library) item.$1]);
      expect(_search(' - '), hasLength(_library.length));
    });

    // query, the names expected first, in order.
    const typos = <(String, List<String>)>[
      ('bnch prss', ['Barbell Bench Press']),
      ('chiken', ['Chicken Breast']),
      ('dumbel', ['Dumbbell Curl']),
      ('deadlfit', ['Romanian Deadlift']),
      ('creme fraiche', ['Crème Fraîche']),
      ('CRÈME', ['Crème Fraîche']),
      ('pullup', ['Pull-Up']),
    ];
    for (final (query, expected) in typos) {
      test('"$query" finds ${expected.join(', ')}', () {
        expect(_search(query).take(expected.length), expected);
      });
    }

    test('ranks a whole match, then a start, a word, anywhere', () {
      final items = ['Overpressure', 'Bench Press', 'Press Machine', 'Press'];
      expect(
        FuzzyMatch.search(
          items,
          'press',
          (name) => [
            [name],
          ],
        ),
        ['Press', 'Press Machine', 'Bench Press', 'Overpressure'],
      );
    });

    test('ranks earlier fields first, and literal before fuzzy', () {
      // "Seated Row" matches by name; "Machine Chest Press" only by its
      // other name; "Romanian Deadlift" holds no "seated" at all.
      expect(_search('seated'), ['Seated Row', 'Machine Chest Press']);
      // "chest" is in one name and in another's description.
      expect(_search('chest'), ['Machine Chest Press', 'Seated Row']);
      // A literal "chick" beats a fuzzy "chiken" match below it.
      expect(_search('chicken').first, 'Chicken Breast');
      expect(_search('chicken'), isNot(contains('Chickpeas')));
    });

    test('equal matches keep the order they came in', () {
      expect(_search('barbell'), ['Barbell Bench Press', 'Barbell Squat']);
    });

    test('short queries match only as typed', () {
      expect(_search('sqat'), isEmpty);
      expect(_search('rdl'), ['Romanian Deadlift']);
      expect(_search('ch').first, 'Chicken Breast');
    });

    test('lists nothing for a query that matches nothing', () {
      expect(_search('xyz'), isEmpty);
      expect(_search('zzzzzz'), isEmpty);
    });

    test('a query past 32 letters matches only as typed', () {
      expect(_search('lying on a bench press the bar extra'), isEmpty);
      expect(_search('lying on a bench press the bar'), [
        'Barbell Bench Press',
      ]);
    });

    test('with anyWord, one word is enough, below a whole match', () {
      expect(_search('squat curl'), isEmpty);
      expect(_search('squat curl', anyWord: true), [
        'Barbell Squat',
        'Dumbbell Curl',
      ]);
      expect(_search('seated row', anyWord: true), [
        'Seated Row',
        'Machine Chest Press',
      ]);
      expect(_search('squat', anyWord: true), ['Barbell Squat']);
    });
  });
}
