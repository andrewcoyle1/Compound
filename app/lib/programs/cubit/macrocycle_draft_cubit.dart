import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:program_repository/program_repository.dart';

/// A macrocycle being edited (Swift `MacrocycleDetailPresenter`'s fields):
/// its name, its mesocycles in order (one may appear twice), and where to
/// start it, both from 0.
final class const MacrocycleDraft({
  final String name = '',
  final List<String> mesocycleIds = const [],
  final int startMesocycleIndex = 0,
  final int startMicrocycleIndex = 0,
}) extends Equatable {
  /// Whether it can be saved or started: a name and a mesocycle.
  bool get canSave => name.trim().isNotEmpty && mesocycleIds.isNotEmpty;

  /// How many microcycles the chosen starting mesocycle has, at least one.
  int startMicrocycleCount(List<Mesocycle> mesocycles) {
    final id = startMesocycleIndex < mesocycleIds.length
        ? mesocycleIds[startMesocycleIndex]
        : null;
    final count =
        mesocycles.where((m) => m.id == id).firstOrNull?.numMicrocycles ?? 1;
    return count < 1 ? 1 : count;
  }

  /// [existing] with these edits, or a new, unstarted macrocycle by
  /// [authorId].
  Macrocycle edited({
    required Macrocycle? existing,
    required String authorId,
    required String Function() newId,
    required DateTime now,
  }) {
    final base =
        existing ??
        Macrocycle(
          id: newId(),
          authorId: authorId,
          name: name.trim(),
          mesocycleIds: mesocycleIds,
          status: MacrocycleStatus.notStarted,
          mesocycleStartedAt: now,
          dateCreated: now,
          dateModified: now,
        );
    return base.copyWith(
      dateModified: base.dateModified,
      startMicrocycleIndex: base.startMicrocycleIndex,
      name: name.trim(),
      mesocycleIds: mesocycleIds,
    );
  }

  MacrocycleDraft copyWith({
    String? name,
    List<String>? mesocycleIds,
    int? startMesocycleIndex,
    int? startMicrocycleIndex,
  }) => MacrocycleDraft(
    name: name ?? this.name,
    mesocycleIds: mesocycleIds ?? this.mesocycleIds,
    startMesocycleIndex: startMesocycleIndex ?? this.startMesocycleIndex,
    startMicrocycleIndex: startMicrocycleIndex ?? this.startMicrocycleIndex,
  );

  @override
  List<Object?> get props => [
    name,
    mesocycleIds,
    startMesocycleIndex,
    startMicrocycleIndex,
  ];
}

/// Edits a [MacrocycleDraft], keeping its start point in range.
class MacrocycleDraftCubit extends Cubit<MacrocycleDraft> {
  /// Starts from `existing`, or empty for a new macrocycle. `mesocycles`
  /// are the user's, for the microcycle counts.
  new({required this._mesocycles, Macrocycle? existing})
    : super(
        MacrocycleDraft(
          name: existing?.name ?? '',
          mesocycleIds: existing?.mesocycleIds ?? const [],
        ),
      );

  List<Mesocycle> _mesocycles;

  /// The user's mesocycles changed.
  // ponytail: only the start-point clamp reads them; no state to emit.
  // ignore: use_setters_to_change_properties
  void mesocyclesChanged(List<Mesocycle> mesocycles) =>
      _mesocycles = mesocycles;

  void nameChanged(String name) => emit(state.copyWith(name: name));

  /// Adds [mesocycle] at the end; an unnamed macrocycle takes its name.
  void added(Mesocycle mesocycle) => emit(
    state.copyWith(
      mesocycleIds: [...state.mesocycleIds, mesocycle.id],
      name: state.name.isEmpty ? mesocycle.name : null,
    ),
  );

  /// Moves the mesocycle at [from] to [to], its place once moved.
  void moved(int from, int to) {
    final ids = [...state.mesocycleIds];
    final id = ids.removeAt(from);
    ids.insert(to, id);
    _clamp(state.copyWith(mesocycleIds: ids));
  }

  void removed(int index) => _clamp(
    state.copyWith(mesocycleIds: [...state.mesocycleIds]..removeAt(index)),
  );

  void startMesocycleChanged(int index) =>
      _clamp(state.copyWith(startMesocycleIndex: index));

  void startMicrocycleChanged(int index) =>
      _clamp(state.copyWith(startMicrocycleIndex: index));

  void _clamp(MacrocycleDraft draft) {
    final last = draft.mesocycleIds.isEmpty ? 0 : draft.mesocycleIds.length - 1;
    final meso = draft.startMesocycleIndex.clamp(0, last);
    final clamped = draft.copyWith(startMesocycleIndex: meso);
    final micro = clamped.startMicrocycleIndex.clamp(
      0,
      clamped.startMicrocycleCount(_mesocycles) - 1,
    );
    emit(clamped.copyWith(startMicrocycleIndex: micro));
  }
}
