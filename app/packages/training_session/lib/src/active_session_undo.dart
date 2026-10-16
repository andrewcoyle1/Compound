part of 'active_session_controller.dart';

/// What an undo or redo would do, for the app to word ("Undo Log Set 2").
enum UndoKind { logSet, unlogSet, deleteSet, changeReps }

/// An undo's name: its kind, and for a log or un-log the set's number as
/// shown ("2", "1L").
@immutable
class const UndoName(final UndoKind kind, {final String? setLabel}) {
  @override
  bool operator ==(Object other) =>
      other is UndoName && other.kind == kind && other.setLabel == setLabel;

  @override
  int get hashCode => Object.hash(kind, setLabel);
}

/// The window's `UndoManager`, as much of it as the tracker used: one entry
/// per action; an action registered while undoing goes on the redo stack
/// under the name of what was undone, and anything new clears the redos.
class _UndoStack {
  final List<(UndoName, void Function())> _undos = [];
  final List<(UndoName, void Function())> _redos = [];
  UndoName? _undoing;
  bool _redoing = false;

  /// The set whose reps taps undo as one; any other registration ends it.
  String? coalescingRepsSetId;

  UndoName? get undoName => _undos.lastOrNull?.$1;

  UndoName? get redoName => _redos.lastOrNull?.$1;

  void register(UndoName name, void Function() action) {
    coalescingRepsSetId = null;
    if (_undoing case final undone?) {
      _redos.add((undone, action));
    } else {
      _undos.add((name, action));
      if (!_redoing) _redos.clear();
    }
  }

  void undo() {
    if (_undos.isEmpty) return;
    final (name, action) = _undos.removeLast();
    _undoing = name;
    try {
      action();
    } finally {
      _undoing = null;
    }
  }

  void redo() {
    if (_redos.isEmpty) return;
    final (_, action) = _redos.removeLast();
    _redoing = true;
    try {
      action();
    } finally {
      _redoing = false;
    }
  }

  void clear() {
    _undos.clear();
    _redos.clear();
    coalescingRepsSetId = null;
  }
}
