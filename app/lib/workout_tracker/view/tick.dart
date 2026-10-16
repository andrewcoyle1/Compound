import 'dart:async';

import 'package:compound/workout_tracker/logic/tracker_clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Rebuilds [builder] every second with the time, for the workout clock
/// and the rest's countdown.
class Tick extends StatefulWidget {
  const new({required this.builder, super.key});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<Tick> createState() => _TickState();
}

class _TickState extends State<Tick> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = context.read<TrackerClock?>() ?? const TrackerClock();
    return widget.builder(context, clock.now());
  }
}
