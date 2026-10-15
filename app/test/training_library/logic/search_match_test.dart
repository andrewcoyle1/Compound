import 'package:compound/training_library/training_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(SearchMatch, () {
    test('ignores case and the punctuation around the query', () {
      expect(SearchMatch.matches('flat press!', ['Flat Press']), isTrue);
      expect(SearchMatch.matches('  QUADS ', [null, 'quads']), isTrue);
      expect(SearchMatch.matches('zzz', ['Bench Press']), isFalse);
    });

    test('a blank query matches nothing and is not a search', () {
      expect(SearchMatch.matches(' !? ', ['anything']), isFalse);
      expect(SearchMatch.isSearching(' !? '), isFalse);
      expect(SearchMatch.isSearching('a'), isTrue);
    });
  });
}
