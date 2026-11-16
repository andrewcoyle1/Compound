import 'dart:async';

/// Deletes the user has asked for but can still undo: each is hidden from
/// the lists at once, and written only when its Undo window closes.
///
/// A key names what is deleted, usually its Firestore document path, so the
/// blocs listing those documents can hide it ([HidePending.hide]). The
/// commit captures repositories, never a cubit or a context, because the
/// screen that asked may be gone by the time it runs.
///
/// Every pending delete is committed when the app goes to the background
/// and before the user signs out ([flushAll]). A delete still pending when
/// the app is killed is never written: the item survives, which is the safe
/// way to fail.
class PendingDeletes {
  final _commits = <String, Future<void> Function()>{};
  final _changes = StreamController<Set<String>>.broadcast();

  /// The keys waiting for their Undo window to close.
  Set<String> get keys => Set.unmodifiable(_commits.keys);

  /// [keys] now, then each time they change.
  Stream<Set<String>> watch() async* {
    yield keys;
    yield* _changes.stream;
  }

  /// Whether [key] is waiting.
  bool contains(String key) => _commits.containsKey(key);

  /// Hides [key] until [commit] or [undo]. Scheduling a key already waiting
  /// replaces its commit.
  void schedule(String key, Future<void> Function() commit) {
    _commits[key] = commit;
    _changed();
  }

  /// Drops [key] without writing anything, so it shows again. Whether it was
  /// waiting.
  bool undo(String key) {
    final waiting = _commits.remove(key) != null;
    if (waiting) _changed();
    return waiting;
  }

  /// Writes [key]'s delete. It stays hidden until the write is done, so the
  /// lists drop it before it would show again; if the write throws, it shows
  /// again and the error is rethrown.
  Future<void> commit(String key) async {
    final commit = _commits[key];
    if (commit == null) return;
    try {
      await commit();
    } finally {
      // Undo cannot reach it once its commit has started, so only this
      // commit removes it.
      if (identical(_commits[key], commit)) {
        _commits.remove(key);
        _changed();
      }
    }
  }

  /// Commits every waiting delete; each that fails shows again.
  Future<void> flushAll() async {
    await Future.wait([
      for (final key in keys)
        commit(key).then<void>((_) {}, onError: (Object _) {}),
    ]);
  }

  /// Stops telling listeners; the app does this as it closes.
  Future<void> close() => _changes.close();

  void _changed() {
    if (!_changes.isClosed) _changes.add(keys);
  }
}

/// The keys deletes wait under in [PendingDeletes], one kind of document
/// each, so the screen deleting and the lists hiding agree.
abstract final class PendingKeys {
  /// A gym profile.
  static String gym(String id) => 'gym_profiles/$id';

  /// A mesocycle.
  static String mesocycle(String id) => 'mesocycles/$id';

  /// An exercise of the user's own.
  static String exercise(String id) => 'exercises/$id';

  /// A workout template.
  static String template(String id) => 'workout_templates/$id';

  /// A progress photo.
  static String photo(String id) => 'progress_photos/$id';

  /// A comment on a workout.
  static String comment(String id) => 'comments/$id';

  /// A chat with the coach.
  static String coachChat(String id) => 'coach_chats/$id';

  /// A weigh-in.
  static String weighIn(String id) => 'weight_entries/$id';

  /// A food of the user's own.
  static String food(String id) => 'foods/$id';

  /// A recipe of the user's own.
  static String recipe(String id) => 'recipes/$id';

  /// A logged meal.
  static String meal(String id) => 'meals/$id';

  /// One food in a meal.
  static String mealItem(String mealId, String itemId) =>
      'meals/$mealId/items/$itemId';
}

/// Hides the items waiting to be deleted.
extension HidePending<T> on Iterable<T> {
  /// The items whose [keyOf] is not in [pending].
  List<T> hide(Set<String> pending, String Function(T item) keyOf) => [
    for (final item in this)
      if (!pending.contains(keyOf(item))) item,
  ];
}
