/// The time the tracker reads, shared by `ActiveWorkoutCubit` and the
/// screens that count down from it, so tests can move both together.
class TrackerClock {
  const new([this.now = DateTime.now]);

  final DateTime Function() now;
}
