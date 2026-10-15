/// How the tabs' search fields match (Swift `SearchMatch`): a substring of
/// the normalised query against each normalised field.
abstract final class SearchMatch {
  static final _edges = RegExp(
    r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$',
    unicode: true,
  );

  /// Lower case, with spaces and punctuation trimmed from both ends.
  static String normalised(String text) =>
      text.replaceAll(_edges, '').toLowerCase();

  /// Whether [query] says anything once normalised.
  static bool isSearching(String query) => normalised(query).isNotEmpty;

  /// Whether any of [fields] contains [query]. False for a blank query, so a
  /// caller never has to ask whether it is searching.
  static bool matches(String query, Iterable<String?> fields) {
    final normalisedQuery = normalised(query);
    if (normalisedQuery.isEmpty) return false;
    return fields.any(
      (field) => field != null && normalised(field).contains(normalisedQuery),
    );
  }
}
