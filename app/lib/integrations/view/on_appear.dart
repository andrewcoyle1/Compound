import 'package:flutter/widgets.dart';

/// Calls [onAppear] once, when it first enters the tree: work a Swift
/// presenter starts from `onAppear`, such as asking Apple Health for what
/// changed.
class OnAppear extends StatefulWidget {
  const new({required this.onAppear, required this.child, super.key});

  final VoidCallback onAppear;
  final Widget child;

  @override
  State<OnAppear> createState() => _OnAppearState();
}

class _OnAppearState extends State<OnAppear> {
  @override
  void initState() {
    super.initState();
    widget.onAppear();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
