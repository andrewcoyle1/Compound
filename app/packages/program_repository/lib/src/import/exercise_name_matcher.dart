import 'package:compound_models/compound_models.dart';

/// A sheet's exercise name to a library exercise (Swift
/// `ExerciseNameMatcher`), strictest rule first: the exact name, an
/// alternate name, the same words ignoring case and punctuation, the same
/// words once abbreviations are spelled out ("DB" is "Dumbbell"), the same
/// words in any order, a library name that only adds a position or
/// equipment word, and a sheet name that only adds words to a library
/// name. Never a fuzzy guess: a rule that fits more than one exercise fits
/// none, and a word that defines the lift is never waved through.
/// `suggestions` ranks the nearest names for the review screen instead.
class ExerciseNameMatcher {
  /// Creates an [ExerciseNameMatcher] over a library of exercises.
  new(this._library)
    : _entries = [
        for (final exercise in _library)
          (exercise, [for (final name in _names(exercise)) _words(name)]),
      ];

  final List<ExerciseModel> _library;

  /// Each exercise's name and alternates as word sets.
  final List<(ExerciseModel, List<Set<String>>)> _entries;

  /// The library exercise [name] is, or null when no rule picks one.
  ExerciseModel? match(String name) {
    final trimmed = name.trim();
    return _library.where((e) => e.name == trimmed).firstOrNull ??
        _library.where((e) => e.alternateNames.contains(trimmed)).firstOrNull ??
        _uniqueKey(_normalized(trimmed), _normalized) ??
        _uniqueKey(_expanded(trimmed), _expanded) ??
        _byWords(_words(trimmed));
  }

  ExerciseModel? _byWords(Set<String> words) {
    if (words.length < 2) return null;
    return _unique((form) => _sameSet(form, words)) ??
        _unique(
          (form) =>
              !form.every(words.contains) &&
              words.every(form.contains) &&
              form.difference(words).every(_qualifiers.contains),
        ) ??
        _longestContained(words);
  }

  /// Up to [limit] exercises nearest to [name] by the words they share,
  /// best first. Empty when nothing shares a word.
  List<ExerciseModel> suggestions(String name, {int limit = 3}) {
    final words = _words(name);
    if (words.isEmpty) return const [];
    final scored =
        [
          for (final (exercise, forms) in _entries)
            if (forms
                    .map((form) {
                      final shared = form.intersection(words).length;
                      return shared == 0
                          ? 0.0
                          : shared / form.union(words).length;
                    })
                    .fold<double>(0, (a, b) => a > b ? a : b)
                case final best when best > 0)
              (best, exercise),
        ]..sort(
          (a, b) => a.$1 == b.$1
              ? a.$2.name.compareTo(b.$2.name)
              : b.$1.compareTo(a.$1),
        );
    return [for (final (_, exercise) in scored.take(limit)) exercise];
  }

  /// The one exercise with a name or alternate that has [key] under
  /// [form], or null when none or several do.
  ExerciseModel? _uniqueKey(String key, String Function(String) form) {
    if (key.isEmpty) return null;
    return _one(
      _library.where(
        (exercise) => _names(exercise).any((name) => form(name) == key),
      ),
    );
  }

  /// The one exercise with a name or alternate whose words pass [test].
  ExerciseModel? _unique(bool Function(Set<String>) test) => _one([
    for (final (exercise, forms) in _entries)
      if (forms.any(test)) exercise,
  ]);

  /// The library name the sheet's name only adds words to, the longest such
  /// name when it is the only one of its length. A one-word library name
  /// is never taken, nor one the added words make a different lift.
  ExerciseModel? _longestContained(Set<String> words) {
    final best = [
      for (final (exercise, forms) in _entries)
        for (final form in forms)
          if (form.length >= 2 &&
              form.every(words.contains) &&
              !_changesTheLift(words.difference(form), exercise))
            (form.length, exercise),
    ];
    if (best.isEmpty) return null;
    final longest = best
        .map((entry) => entry.$1)
        .reduce((a, b) => a > b ? a : b);
    return _one([
      for (final (count, exercise) in best)
        if (count == longest) exercise,
    ]);
  }

  static ExerciseModel? _one(Iterable<ExerciseModel> matches) =>
      {for (final exercise in matches) exercise.id}.length == 1
      ? matches.first
      : null;

  static List<String> _names(ExerciseModel exercise) => [
    exercise.name,
    ...exercise.alternateNames,
  ];

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.every(b.contains);

  /// Whether words a sheet adds to a library name make it a different
  /// lift: a defining word, or an implement the exercise's own name
  /// contradicts ("DB RDL" is not the barbell one).
  static bool _changesTheLift(Set<String> added, ExerciseModel exercise) {
    if (added.any(_defining.contains)) return true;
    final named = _words(exercise.name).intersection(_implements);
    final addedImplements = added.intersection(_implements);
    return named.isNotEmpty &&
        addedImplements.isNotEmpty &&
        named.intersection(addedImplements).isEmpty;
  }
}

/// Lower-cased words with punctuation dropped: "Pull-Down (Wide)" is "pull
/// down wide".
String _normalized(String name) => name
    .toLowerCase()
    .replaceAll('°', ' degree ')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ' ')
    .split(' ')
    .where((word) => word.isNotEmpty)
    .join(' ');

/// [_normalized], with each abbreviation spelled out.
String _expanded(String name) {
  var words = ' ${_normalized(name)} ';
  for (final (short, long) in _expansions) {
    words = words.replaceAll(' $short ', ' $long ');
  }
  return words.trim();
}

/// [_expanded] as a set of words, parenthetical qualifiers and filler
/// words left out.
Set<String> _words(String name) =>
    _expanded(name.replaceAll(RegExp(r'\([^)]*\)'), ' '))
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toSet()
        .difference(_fillers);

const _fillers = {'the', 'a', 'of', 'with', 'on', 'and', 'w'};

/// Words a library name may add to a sheet's and still be the same lift.
const _qualifiers = {
  'seated',
  'standing',
  'kneeling',
  'lying',
  'cable',
  'machine',
  'lever',
  'pin',
  'loaded',
  'plate',
  'smith',
  'degree',
  '45',
};

/// Grips, attachments and variants that name their own lift.
const _defining = {
  'bayesian',
  'concentration',
  'wrist',
  'reverse',
  'split',
  'wide',
  'close',
  'neutral',
  'dual',
  'single',
  'preacher',
  'spider',
};

const _implements = {
  'dumbbell',
  'barbell',
  'kettlebell',
  'cable',
  'machine',
  'smith',
  'ez',
  'band',
  'lever',
  'trap',
};

const _expansions = [
  ('db', 'dumbbell'),
  ('bb', 'barbell'),
  ('sm', 'smith machine'),
  ('1 arm', 'single arm'),
  ('one arm', 'single arm'),
  ('pulldown', 'pull down'),
  ('flye', 'fly'),
  ('rdl', 'romanian deadlift'),
  ('ez barbell', 'ez bar'),
  ('pressdown', 'pushdown'),
  ('press down', 'pushdown'),
  ('push down', 'pushdown'),
  ('skullcrusher', 'skull crusher'),
  ('hyperextension', 'back extension'),
  ('hamstring curl', 'leg curl'),
];
