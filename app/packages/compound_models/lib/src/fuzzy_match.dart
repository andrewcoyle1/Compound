import 'package:fuzzy/fuzzy.dart';
import 'package:stringr/stringr.dart';

/// How every search field matches: forgiving of typos, case, accents and
/// punctuation, and ranked so the closest results come first.
///
/// A result's place is decided, in order, by:
/// 1. a literal match (the query appears in a field as typed) before a fuzzy
///    one;
/// 2. the field it matched, earlier fields first (the name before the
///    description);
/// 3. how it matched: the whole field, then the field's start, then a word's
///    start, then anywhere, then fuzzily by score;
/// 4. the order the items came in.
abstract final class FuzzyMatch {
  /// The shortest query matched fuzzily. Anything shorter matches only as
  /// typed: one typo in four letters already matches "seat" for "sqat".
  static const fuzzyMinLength = 5;

  static final _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// The fuzzy search's tolerance (Bitap): the share of a query's letters
  /// that may be wrong. 0.26 allows one typo in five to seven letters
  /// ("chiken"), two in eight to eleven ("bnch prss", "deadlfit"), and so
  /// on.
  static final _options = FuzzyOptions<String>(
    threshold: 0.26,
    // How far into a field a match may start before it counts against it:
    // far enough that the start adds next to nothing to the score.
    distance: 10000,
    shouldSort: false,
  );

  /// [text] as compared: lower case, without accents, with each run of
  /// spaces and punctuation as one space, trimmed.
  static String normalised(String text) =>
      text.toLowerCase().latinize().replaceAll(_separators, ' ').trim();

  /// Whether [query] says anything once normalised.
  static bool isSearching(String query) => normalised(query).isNotEmpty;

  /// The [items] matching [query], best first (see [FuzzyMatch]). A blank
  /// query returns every item in its order.
  ///
  /// [fields] gives each item's text, most important first; a field holds
  /// several values when an item has several (alternate names, muscles).
  /// With [anyWord], an item may match one word of a longer query, below
  /// those matching it whole.
  // ponytail: scans every field per keystroke, O(items × text); index the
  // normalised texts if a library grows past a few thousand items.
  static List<T> search<T>(
    Iterable<T> items,
    String query,
    List<Iterable<String?>> Function(T item) fields, {
    bool anyWord = false,
  }) {
    final list = items.toList();
    final needle = normalised(query);
    if (needle.isEmpty) return list;

    // Every text, normalised, with the item and the field it came from.
    final texts = <String>[];
    final owners = <(int, int)>[];
    for (final (index, item) in list.indexed) {
      for (final (field, values) in fields(item).indexed) {
        for (final value in values) {
          final text = value == null ? '' : normalised(value);
          if (text.isEmpty) continue;
          texts.add(text);
          owners.add((index, field));
        }
      }
    }

    // The best rank each item reached:
    // (word only, fuzzy, field, how, fuzzy score, item).
    final best = <int, List<num>>{};
    void offer(
      int text, {
      required bool word,
      required int how,
      num score = 0,
    }) {
      final (index, field) = owners[text];
      final rank = <num>[
        if (word) 1 else 0,
        if (how == 4) 1 else 0,
        field,
        how,
        score,
        index,
      ];
      final current = best[index];
      if (current == null || _compare(rank, current) < 0) best[index] = rank;
    }

    final patterns = {
      needle: false,
      if (anyWord)
        for (final word in needle.split(' '))
          if (word != needle) word: true,
    };
    for (final MapEntry(key: pattern, value: word) in patterns.entries) {
      for (final (text, value) in texts.indexed) {
        final how = _literal(value, pattern);
        if (how != null) offer(text, word: word, how: how);
      }
      // Past Bitap's 32 letters the package matches any one word: too loose.
      if (pattern.length < fuzzyMinLength ||
          pattern.length > _options.maxPatternLength) {
        continue;
      }
      for (final result in Fuzzy(texts, options: _options).search(pattern)) {
        offer(
          result.matches.first.arrayIndex,
          word: word,
          how: 4,
          score: result.score,
        );
      }
    }

    final ranked = best.values.toList()..sort(_compare);
    return [for (final rank in ranked) list[rank.last.toInt()]];
  }

  /// How [pattern] appears in [text] as typed: 0 the whole text, 1 its
  /// start, 2 a word's start, 3 anywhere; null not at all.
  static int? _literal(String text, String pattern) {
    if (text == pattern) return 0;
    if (text.startsWith(pattern)) return 1;
    if (text.contains(' $pattern')) return 2;
    if (text.contains(pattern)) return 3;
    return null;
  }

  static int _compare(List<num> a, List<num> b) {
    for (var i = 0; i < a.length; i++) {
      final order = a[i].compareTo(b[i]);
      if (order != 0) return order;
    }
    return 0;
  }
}
