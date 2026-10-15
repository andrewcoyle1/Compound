import 'package:bloc/bloc.dart';
import 'package:compound/training_library/models/training_library.dart';
import 'package:equatable/equatable.dart';
import 'package:program_repository/program_repository.dart';
import 'package:training_library_repository/training_library_repository.dart';

part 'training_library_event.dart';
part 'training_library_state.dart';

/// The signed-in user's training library, following their exercises,
/// workout templates, gyms and mesocycles together.
class TrainingLibraryBloc
    extends Bloc<TrainingLibraryEvent, TrainingLibraryState> {
  new({
    required this._libraryRepository,
    required this._programRepository,
    required this._uid,
  }) : super(const TrainingLibraryLoading()) {
    on<TrainingLibrarySubscriptionRequested>(_onSubscriptionRequested);
  }

  final TrainingLibraryRepository _libraryRepository;
  final ProgramRepository _programRepository;
  final String _uid;

  Future<void> _onSubscriptionRequested(
    TrainingLibrarySubscriptionRequested event,
    Emitter<TrainingLibraryState> emit,
  ) async {
    emit(const TrainingLibraryLoading());
    List<ExerciseModel>? exercises;
    List<WorkoutTemplateModel>? templates;
    List<GymProfileModel>? gyms;
    List<Mesocycle>? mesocycles;
    var failed = false;

    // Loaded once every list has arrived, and again on each change.
    void update() {
      if (failed) return;
      if (exercises == null ||
          templates == null ||
          gyms == null ||
          mesocycles == null) {
        return;
      }
      emit(
        TrainingLibraryLoaded(
          TrainingLibrary(
            userExercises: exercises!,
            userWorkoutTemplates: templates!,
            gymProfiles: gyms!,
            mesocycles: mesocycles!,
          ),
        ),
      );
    }

    void fail(Object _, StackTrace _) {
      failed = true;
      emit(const TrainingLibraryFailure());
    }

    await Future.wait([
      emit.onEach(
        _libraryRepository.watchUserExercises(_uid),
        onData: (data) {
          exercises = data;
          update();
        },
        onError: fail,
      ),
      emit.onEach(
        _libraryRepository.watchUserWorkoutTemplates(_uid),
        onData: (data) {
          templates = data;
          update();
        },
        onError: fail,
      ),
      emit.onEach(
        _libraryRepository.watchGymProfiles(_uid),
        onData: (data) {
          gyms = data;
          update();
        },
        onError: fail,
      ),
      emit.onEach(
        _programRepository.watchMesocycles(_uid),
        onData: (data) {
          mesocycles = data;
          update();
        },
        onError: fail,
      ),
    ]);
  }
}
